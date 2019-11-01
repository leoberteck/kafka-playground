select count(1) from sgpa_map.ddn_mapa 
where cd_cliente = 4
and fg_fluxo = 'N'
and fg_estagio_processamento = 1
and fg_processamento = 'D'

select * from sgpa_map.cdt_cliente where cd_id = 17

select * from sgpa_map.cdt_talhao 
where cd_cliente = 4
and cd_unidade = 2
and cd_fazenda = '2'
and cd_zona = '4'
and cd_talhao = '17';

select * from sgpa_map.cdt_operacao where cd_cliente = 4 and cd_operacao = '340';



select * from sgpa_map.fnc_gerar_sobreposicao(4, (
	select array_agg(cd_id) from sgpa_map.trecho_operacao_talhao
	where cd_cliente = 4
	and cd_talhao = 3961178
	and cd_operacao = 2573
	and dt_dia in ('2019-10-10', '2019-10-11')
	and fg_status = 'A'
));

create or replace function workspace_leonardo.fnc_tmp_trechos() returns bigint[]
immutable 
parallel safe
language plpgsql
as $$
begin
	return (
		select array_agg(cd_id) from sgpa_map.trecho_operacao_talhao
		where cd_cliente = 4
		and cd_talhao = 3961178
		and cd_operacao = 2573
		and dt_dia in ('2019-10-10', '2019-10-11')
		and fg_status = 'A'
	);
end;
$$;

select * from sgpa_map.fnc_agg_with_superposition(t.vl_geom_arr, ci.vl_espacamento_total)

explain analyse with dataset as (
    select dm.cd_cliente
    , dm.cd_id_equipamento
    --Colunas da quebra
    , dm.cd_id_implemento
    , dm.cd_id_talhao
    , dm.cd_id_operacao_cb
    , dm.cd_id_equipe
    , dm.cd_id_operador
    , dm.cd_id_jornada
    , dm.dt_hr_utc_inicial
    , dm.dt_hr_utc_final
    , dm.dt_hr_local_inicial::date dt_dia
    , dm.vl_timezone
    --Dados para gerar geometria do implemento
    , dm.linha
    , dm.vl_secao_pulverizador
    , dm.vl_largura_implemento
    , case ci.fg_tratar_secoes when '2' then dm.vl_largura_implemento::text else dm.vl_secao_pulverizador end as quebra_secao
    from unnest(workspace_leonardo.fnc_tmp_trechos()) tot_id
    join sgpa_map.trecho_operacao_talhao tot on (tot.cd_cliente = 4 and tot.cd_id = tot_id)
    cross join unnest(tot.vl_kijos_arr) kijo_id
    join sgpa_map.ddn_mapa dm on (dm.cd_cliente = 4 and dm.cd_id = kijo_id and dm.cd_id_equipamento > -1 and dm.cd_id_talhao > -1 and dm.cd_estado = 'E' )
    join sgpa_map.cdt_implemento ci on (dm.cd_id_implemento = ci.cd_id)
  )
  , lead_quebra as (
    select 
      d.cd_cliente
      , d.cd_id_equipamento
      , d.cd_id_implemento
      , d.cd_id_talhao
      , d.cd_id_operacao_cb
      , d.cd_id_equipe
      , d.cd_id_operador
      , d.cd_id_jornada
      , d.dt_hr_utc_inicial
      , d.dt_dia
      , d.quebra_secao
      , d.vl_timezone
      , lead(d.cd_id_implemento) over (partition by d.cd_cliente, d.cd_id_equipamento order by d.dt_hr_utc_inicial) as ld_cd_id_implemento
      , lead(d.cd_id_talhao) over (partition by d.cd_cliente, d.cd_id_equipamento order by d.dt_hr_utc_inicial) as ld_cd_id_talhao
      , lead(d.cd_id_operacao_cb) over (partition by d.cd_cliente, d.cd_id_equipamento order by d.dt_hr_utc_inicial) as ld_cd_id_operacao_cb
      , lead(d.cd_id_equipe) over (partition by d.cd_cliente, d.cd_id_equipamento order by d.dt_hr_utc_inicial) as ld_cd_id_equipe
      , lead(d.cd_id_operador) over (partition by d.cd_cliente, d.cd_id_equipamento order by d.dt_hr_utc_inicial) as ld_cd_id_operador
      , lead(d.cd_id_jornada) over (partition by d.cd_cliente, d.cd_id_equipamento order by d.dt_hr_utc_inicial) as ld_cd_id_jornada
      , lead(d.dt_dia) over (partition by d.cd_cliente, d.cd_id_equipamento order by d.dt_hr_utc_inicial) as ld_dt_dia
      , lead(d.quebra_secao) over (partition by d.cd_cliente, d.cd_id_equipamento order by d.dt_hr_utc_inicial) as ld_quebra_secao
      , lead(d.vl_timezone) over (partition by d.cd_cliente, d.cd_id_equipamento order by d.dt_hr_utc_inicial) as ld_vl_timezone
    from dataset d
  ), quebras_1 as (
    select 
      d.cd_cliente
      , d.cd_id_equipamento
      , d.dt_hr_utc_inicial
      , lag(d.dt_hr_utc_inicial) over (partition by d.cd_cliente, d.cd_id_equipamento order by d.dt_hr_utc_inicial) dt_hr_anterior
      , max(d.dt_hr_utc_inicial) over (partition by d.cd_cliente, d.cd_id_equipamento) max_dt_equipamento
      , row_number() over (partition by d.cd_cliente, d.cd_id_equipamento order by d.dt_hr_utc_inicial) rn
    from lead_quebra d
    where d.cd_id_implemento <> d.ld_cd_id_implemento
    or d.cd_id_talhao <> d.ld_cd_id_talhao
    or d.cd_id_operacao_cb <> d.ld_cd_id_operacao_cb
    or d.cd_id_equipe <> d.ld_cd_id_equipe
    or d.cd_id_operador <> d.ld_cd_id_operador
    or d.cd_id_jornada <> d.ld_cd_id_jornada
    or d.dt_dia <> d.ld_dt_dia
    or d.quebra_secao <> d.ld_quebra_secao
    or d.vl_timezone <> d.ld_vl_timezone
  ), quebras_2 as (
    --Retorna a ultima quebra
    select q2.cd_cliente, q2.cd_id_equipamento, null::timestamp as dt_hr_utc_inicial, q2.max_dt_equipamento dt_hr_anterior from quebras_1 q2
    where q2.rn = 1
  ), quebras as (
    select q1.cd_cliente, q1.cd_id_equipamento, q1.dt_hr_utc_inicial, q1.dt_hr_anterior from quebras_1 q1
    union all
    select q2.cd_cliente, q2.cd_id_equipamento, q2.dt_hr_utc_inicial, q2.dt_hr_anterior from quebras_2 q2
    order by cd_cliente, cd_id_equipamento, dt_hr_utc_inicial
  ), trechos as (
    select d.cd_cliente
    , d.cd_id_equipamento
    , d.cd_id_implemento
    , d.cd_id_talhao
    , d.cd_id_operacao_cb
    , d.cd_id_equipe
    , d.cd_id_operador
    , d.cd_id_jornada
    , d.dt_dia
    , d.vl_secao_pulverizador
    , d.vl_largura_implemento
    , d.vl_timezone
    , min(d.dt_hr_utc_inicial) dt_inicial
    , max(d.dt_hr_utc_final) dt_final
    , array_agg(d.linha order by d.dt_hr_utc_inicial) vl_geom_arr
    from dataset d
    join quebras q on (
      d.cd_cliente = q.cd_cliente
      and d.cd_id_equipamento = q.cd_id_equipamento
      and d.dt_hr_utc_inicial > coalesce(q.dt_hr_anterior, to_timestamp(0))
      and d.dt_hr_utc_inicial <= coalesce(q.dt_hr_utc_inicial, d.dt_hr_utc_inicial)
    )
    group by d.cd_cliente
    , d.cd_id_equipamento
    , d.cd_id_implemento
    , d.cd_id_talhao
    , d.cd_id_operacao_cb
    , d.cd_id_equipe
    , d.cd_id_operador
    , d.cd_id_jornada
    , d.dt_dia
    , d.vl_secao_pulverizador
    , d.vl_largura_implemento
    , q.dt_hr_anterior
    , q.dt_hr_utc_inicial
    , d.vl_timezone
    order by d.cd_cliente, d.cd_id_equipamento, d.dt_dia
  )
    select t.*, (select array_agg(ws) from sgpa_map.fnc_agg_with_superposition(t.vl_geom_arr, ci.vl_espacamento_total) ws)
	from trechos t
    join sgpa_map.cdt_implemento ci on (ci.cd_id = t.cd_id_implemento)
 ;
  , resultado as (
    select t.cd_cliente                        
    , t.cd_id_equipamento                      
    , t.cd_id_implemento                       
    , t.cd_id_talhao                           
    , t.cd_id_operacao_cb                      
    , t.cd_id_equipe                           
    , t.cd_id_operador                         
    , t.cd_id_jornada                          
    , t.dt_dia                                 
    , t.vl_secao_pulverizador                  
    , t.vl_largura_implemento                  
    , t.dt_inicial                             
    , t.dt_final                               
    , t.vl_timezone                            
    , l.linha                                    
    , l.rn::smallint as fg_part                         
    , vl_secoes_array                          
    , g.geom                                   
    , ST_Area(g.geom::geography) vl_area_metros
    from trechos t
    join sgpa_map.cdt_implemento ci on (ci.cd_id = t.cd_id_implemento)
    join sgpa_map.cdt_talhao ct on (ct.cd_id = t.cd_id_talhao)
    cross join lateral (select row_number() over (order by 1) as rn, linha from sgpa_map.fnc_agg_with_superposition(t.vl_geom_arr, ci.vl_espacamento_total) linha) l
    cross join lateral sgpa_map.fnc_get_dados_implemento(
      t.cd_id_implemento
      , l.linha
      , t.vl_secao_pulverizador
      , t.vl_largura_implemento
      , ci.vl_espacamento_total
      , ci.vl_distancia_entre_secoes
      , ci.fg_tratar_secoes
      , ci.cd_secao_centro
      , ARRAY[
        ci.vl_distancia_centro_secao1,
        ci.vl_distancia_centro_secao2,
        ci.vl_distancia_centro_secao3,
        ci.vl_distancia_centro_secao4,
        ci.vl_distancia_centro_secao5,
        ci.vl_distancia_centro_secao6,
        ci.vl_distancia_centro_secao7,
        ci.vl_distancia_centro_secao8,
        ci.vl_distancia_centro_secao9,
        ci.vl_distancia_centro_secao10,
        ci.vl_distancia_centro_secao11
      ]::numeric[]
      , ARRAY[
        ci.vl_espacamento_secao1,
        ci.vl_espacamento_secao2,
        ci.vl_espacamento_secao3,
        ci.vl_espacamento_secao4,
        ci.vl_espacamento_secao5,
        ci.vl_espacamento_secao6,
        ci.vl_espacamento_secao7,
        ci.vl_espacamento_secao8,
        ci.vl_espacamento_secao9,
        ci.vl_espacamento_secao10,
        ci.vl_espacamento_secao11
      ]::numeric[]
    ) vl_secoes_array
    cross join lateral ( 
      select ST_MakeValid(
          ST_Buffer(
            case when array_length(vl_secoes_array, 1) > 1 then
              ST_Buffer(
                z.geom::geography
                , (case ci.vl_distancia_entre_secoes when 0 then 0.1 else ci.vl_distancia_entre_secoes/2 end)
                , 'endcap=flat'
              )::geometry
            else z.geom end
            , 0
          )
        ) as geom
      from (
        select 
          ST_Makevalid(
            ST_Intersection(
              ST_Makevalid(
                ST_Union(s.geom)
              ), ST_Makevalid(ct.geom)
            )
          ) as geom 
        from unnest(vl_secoes_array) s where s.ativo = true
      ) z
    ) g
  ) 
  select distinct on (
      t.cd_cliente
      , t.cd_id_equipamento
      , t.cd_id_implemento
      , t.cd_id_talhao
      , t.cd_id_operacao_cb
      , t.cd_id_equipe
      , t.cd_id_operador
      , t.cd_id_jornada
      , t.vl_secao_pulverizador
      , t.vl_largura_implemento
      , t.dt_inicial
      , t.dt_final
      , t.vl_timezone
      , t.fg_part
    )
    t.cd_cliente                        
    , t.cd_id_equipamento                      
    , t.cd_id_implemento                       
    , t.cd_id_talhao                           
    , t.cd_id_operacao_cb                      
    , t.cd_id_equipe                           
    , t.cd_id_operador                         
    , t.cd_id_jornada                          
    , t.dt_dia                                 
    , t.vl_secao_pulverizador                  
    , t.vl_largura_implemento                  
    , t.dt_inicial                             
    , t.dt_final                               
    , t.vl_timezone                            
    , t.linha
    , t.fg_part                     
    , t.vl_secoes_array                          
    , t.geom                                   
    , t.vl_area_metros
  from resultado t
  
  
  
  
  
drop function if exists workspace_leonardo.fnc_agg_with_superposition cascade;
create or replace function workspace_leonardo.fnc_agg_with_superposition(p_geom_arr geometry[], p_vl_largura_total float)
returns setof geometry
immutable
cost 1000
strict
parallel safe
language plpgsql
as $$
declare
  v_rec record := null;
  v_geom geometry := null;
  v_line geometry := null;
  v_tolerancia float := (power(p_vl_largura_total,2) * 0.2)::float;
begin
  for v_rec in (
    select t.g, t.bg, lead(t.bg, 2) over (order by t.i) ld_bg from (
      select g
        , ST_Makevalid(ST_Buffer(g::geography, p_vl_largura_total/2, 'join=round endcap=flat')::geometry) bg
        , i
      from unnest(p_geom_arr) with ordinality as T(g, i) order by i
    ) t
  ) loop
    if v_geom is null then
      v_geom := v_rec.bg;
      v_line := v_rec.g;
    else 
      v_geom := ST_Makevalid(st_union(v_geom, v_rec.bg));
      v_line := st_linemerge(st_union(v_line, v_rec.g));      
    end if;
    
    if st_area(st_intersection(v_geom, v_rec.ld_bg)::geography) > v_tolerancia then
      return next ST_Makevalid(v_line);
      v_line := null;
      v_geom := null;
    end if;
  end loop;
  if v_geom is not null then
    return next ST_Makevalid(v_line);
  end if;
  return; 
end;
$$;