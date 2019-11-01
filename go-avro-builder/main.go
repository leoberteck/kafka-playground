package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
)

func main() {
	var err error
	escape := false
	inputFolder := "."
	outputFolder := "."
	file := ""

	args := os.Args[1:]

	for i, arg := range args {
		switch arg {
		case "-e":
			fallthrough
		case "--escape":
			escape = true
		case "-i":
			fallthrough
		case "--input-folder":
			inputFolder, err = safeGet(args, i+1)
			if err != nil {
				panic(errors.New("Could not find input folder argument value. Usage:\n '-i <path/to/folder>' \nor\n '--input-folder <path/to/folder>' "))
			}
		case "-o":
			fallthrough
		case "--output-folder":
			outputFolder, err = safeGet(args, i+1)
			if err != nil {
				panic(errors.New("Could not find output folder argument value. Usage:\n '-o <path/to/folder>' \nor\n '--output-folder <path/to/folder>' "))
			}
		case "-f":
			fallthrough
		case "--file":
			file, err = safeGet(args, i+1)
			if err != nil {
				panic(errors.New("Could not find file argument value. Usage:\n '-f <path/to/file>' \nor\n '--file <path/to/file>' "))
			}
		case "-h":
			fallthrough
		case "--help":
			fmt.Printf(`
	Welcome to go-avro-builder

	Written in golang, this is a program that converts .json files 
	into .avro files, converting the json object to a string 
	and escaping the necessary characters.

	-e or --escape
		replaces " with \"

	-i or --input-folder followed by path/to/folder
		will scan this folder for .json files to convert
	
	-o or --output-folder followed by path/to/folder
		will write the converted files to this folder

	-f or --file followed by path/to/file.json
		for conversion of a single file
	
	-h or --help 
		show the help menu
`)
			os.Exit(1)
		}
	}

	if inputFolder == "" && outputFolder == "" && file == "" {
		panic(errors.New("No arguments provided"))
	}

	wg := &sync.WaitGroup{}
	eChan := make(chan error)

	go listenToErrors(&eChan)

	err = filepath.Walk(inputFolder, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if filepath.Ext(path) == ".json" {
			wg.Add(1)
			go process(wg, &eChan, inputFolder, outputFolder, info.Name(), escape)
		}

		return nil
	})

	if err != nil {
		panic(err)
	}

	wg.Wait()

	fmt.Println("Done")
	os.Exit(1)
}

func safeGet(s []string, i int) (string, error) {
	if i >= len(s) {
		return "", errors.New("Index out of range")
	}
	if i < 0 {
		return "", errors.New("Index negative")
	}
	return s[i], nil
}

func listenToErrors(eChan *chan error) {
	for err := range *eChan {
		fmt.Println(err)
	}
}

func process(wg *sync.WaitGroup, eChan *chan error, inputFolder, outputFolder, filename string, escape bool) {
	defer wg.Done()
	//Read File

	minifyRegex := map[string]string{
		`\n`:   "",
		` +"`:  `"`,
		`" +`:  `"`,
		` +{`:  "{",
		`{ +`:  "{",
		` +\[`: `[`,
		`\[ +`: `[`,
		`} +`:  "}",
		` +}`:  "}",
		`\] +`: `]`,
		` +\]`: `]`,
	}

	dat, err := ioutil.ReadFile(filepath.Join(inputFolder, filename))
	if err != nil {
		*eChan <- err
		return
	}
	jsonStr := string(dat)

	//Minify
	for k, v := range minifyRegex {
		re := regexp.MustCompile(k)
		jsonStr = re.ReplaceAllString(jsonStr, v)
	}

	if escape {
		re := regexp.MustCompile(`"`)
		jsonStr = re.ReplaceAllString(jsonStr, `\"`)
		jsonStr = `"` + jsonStr + `"`
	}

	//Write output
	oFile := filepath.Join(outputFolder, strings.TrimSuffix(filename, filepath.Ext(filename))+".avro")
	f, err := os.Create(oFile)
	if err != nil {
		*eChan <- err
		return
	}
	_, err = f.WriteString(jsonStr)
	if err != nil {
		f.Close()
		*eChan <- err
		return
	}
	fmt.Printf("%s have been written successfully \n", oFile)
	err = f.Close()
	if err != nil {
		*eChan <- err
	}
}
