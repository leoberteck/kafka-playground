
update sgpa_map.ddn_mapa dm set fg_estagio_processamento = 1, fg_processamento = 'D'
from (
	select cd_id from sgpa_map.ddn_mapa where cd_cliente = 4
	order by dt_hr_local_inicial desc
	limit 5000
) t
where dm.cd_cliente = 4
and dm.cd_id = t.cd_id;

select count(1) from sgpa_map.ddn_mapa where cd_cliente = 4 and fg_fluxo = 'N' and fg_estagio_processamento = 1 and fg_processamento = 'D'
select count(1) from sgpa_map.ddn_mapa where cd_cliente = 4 and fg_fluxo = 'N' and fg_estagio_processamento = 2 and fg_processamento = 'I'

notify "transaction.insert.ddn_mapa", '{"cd_cliente": 4, "inserted": 5000000}';



select