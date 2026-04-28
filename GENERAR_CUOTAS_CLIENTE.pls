CREATE OR REPLACE procedure generar_cuotas_cliente
(
  p_id_cliente   cliente.id_cliente%type
  ,p_id_secuencia cliente.id_secuencia%type
  ,p_id_contrato  contrato_cliente.id_contrato%type
  ,p_fecha        date
  ,p_monto_cuota  in out cliente.monto_cuota%type
  ,p_mensaje      out varchar2
  ,p_grabar       in boolean
  ,p_form_6000    in varchar2 default 'NO'
) is
  dummy                  char(1);
  v_id_periodo_factura   periodo_factura.id_periodo_factura%type;
  v_cantidad_cuotas      periodo_factura.cant_cuotas%type;
  v_cantidad_cuotas_real periodo_factura.cant_cuotas%type;
  v_periodo_desc         periodo_factura.descripcion%type;
  v_fecha_inicio         contrato_cliente.fecha_inicio%type;
  v_fecha_inicio_real    contrato_cliente.fecha_inicio%type;
  v_fecha_final          contrato_cliente.fecha_final%type;
  v_id_persona           persona.id_persona%type;
  v_cantidad_meses       number(20);
  v_meses                periodo_factura.meses%type;
  v_mes                  periodo_factura.meses%type;
  v_cant_meses           periodo_factura.meses%type;
  v_cantidad_anhos       number(10);
  v_nro_cuotas           cuotas_cliente.nro_cuota%type;
  v_fecha_ingreso        cliente.fecha_ingreso%type;
  v_identificador        varchar2(2) := 'NO';
  v_tipo_contrato        contrato_cliente.tipo_cto_id_tipo_contrato%type;
  v_empresa              contrato_cliente.emp_id_empresa%type;
  v_item                 number(20) := 0;
  v_cant_cuotas          number(20) := 0;
  v_nro_cuotas_u         number(20) := 0;
  v_fecha_a_facturar     date;
  v_amplia_cuota         varchar2(2) := 'NO';
  v_nro_cuotas_n         number(20) := 0;
  v_nueva_cuota          varchar2(2) := 'NO';
  v_cantidad_cuotas_n    number(20);
  v_primera_cuota        varchar2(2);
  v_fecha_maternidad     cliente.fecha_maternidad%type;
  v_fecha_cuota          date;
  v_fecha_tope           date;
  v_cantidad_real        number;
  v_monto_cuota          number;
  v_categoria            cliente.cat_clie_id_categoria_cliente%type;
  v_cant_dias_mes        number;
  v_cant_dias_cob        number;
  v_fecha_ingreso_real   date;
  v_variado              contrato_cliente.cuota_prorrateado%type;
  v_fecha_inicio_real1   contrato_cliente.fecha_inicio%type;
  v_fecha_final_real1    contrato_cliente.fecha_final%type;
  v_prorrateo            varchar2(1) := 'N';
  v_prorrateo_lici       varchar2(2) := 'NO';
  v_prorrateo_nuevo      varchar2(2) := 'NO';
  v_cto_anterior         contrato_cliente.cto_clie_id_contrato%type;
  v_edad                 number;
  v_edad2                number;
  v_fecnac               date;
  v_feccum               date;
  v_monto_cuota1         number;
  v_monto_cuota2         number;
  x_monto_cuota          number;

  v1_plan_id_plan          number;
  v1_mnd_id_moneda         number;
  v1_id_grupo_beneficiario number;
  v1_id_categoria_cliente  number;
  v1_sexo                  varchar2(10);
  v1_id_tarifa             number;
  v1_porc_sobre_uso        number;
  v1_mensaje               varchar2(500);
  v1_fecha_cuota           date;
  v_fecha_tope_cob         date;
  v_cambia_tarifa1         varchar2(2);
  v_cambia_tarifa2         varchar2(2);
  v_cuota_fin_de_mes       varchar2(2);
  v_porc_promo             number;
  v_minusvalido            varchar2(2);
  v_maternidad             varchar2(2);
  v_dia_inic_cto           number;
  v_control_camb_plan      varchar2(1) := 'N';
  v_mostrar                number;
  v_fecha_hasta_test       date;
  -- asignar 1 para que se muestren los dbms_output
  v_depuracion            number := 1;
  v_existe_cuotas         number := 0; --se usa en linea 468 para ver si se genera la primera cuota o no
  v_calc_dias             number;
  v_id_promo              cuotas_cliente.id_tipo_promocion%type;
  v_promo_porcentaje      cuotas_cliente.porc_descuento%type;
  v_promo_cuota_desde     tipo_promocion.cuota_desde%type;
  v_promo_cuota_hasta     tipo_promocion.cuota_hasta%type;
  v_fecha_inicio_contrato contrato_cliente.fecha_inicio%type;
  v_nro_cuo_insert        number;
  v_total_cuo_insert      number;
  v_dias_mes              number; --cantidad de dias a ser evaluados para considerar mes entero

  l_id_tarifa     number;
  l_monto_cuota   number;
  v_monto_cuota_x number;
  v_fecha_nac     date;

  vl_porc_sobre_uso number := 0;
  vl_aumento        number := 0;

  procedure mostrar(p_texto varchar2) is
  begin
    if v_depuracion = 1 then
      dbms_output.put_line(p_texto);
    end if;
  end;
begin

  --obs: lo que se agrego fue para que se puedan ampliar las cuotas, esta ampliacion
  --es solo para los periodos de facturacion cuya cuota = 0;
  -- *****************************************************************
  --
  --    modificado   (dd/mm/yyyy)
  --    caballerof   22/12/2023 - indentado
  --    caballerof   26/12/2023 - se agrega el guardado del id tarifa en la cuota.
  --    sotelos      27/12/2023 - calcular la edad segun la fecha a facturar y recuperar el monto segun la fecha de la cuota y la edad segun la tarifa
  -- *****************************************************************

  begin
    select 'S'
    into   v_control_camb_plan
    from   historico_cliente t
      ,cliente           d
    where  d.id_cliente = p_id_cliente
    and    t.cliente_id_cliente = d.cliente_id_cliente
    and    t.cliente_id_secuencia = d.cliente_id_secuencia
    and    d.id_secuencia = p_id_secuencia
    and    tipo_historico = 'CAMBIO_PLAN'
    order  by fecha desc
    fetch  first 1 row only;
  exception
    when no_data_found then
      v_control_camb_plan := 'N';
  end;
  x_monto_cuota := p_monto_cuota;

  update cliente_tarifa
  set    vigente = 'NO'
  where  cliente_id_cliente = p_id_cliente
  and    cliente_id_secuencia = p_id_secuencia;

  begin
    select cc.fecha_inicio
      ,cc.fecha_final
      ,nvl(cc.cuota_prorrateado, 'NO')
      ,cc.cto_clie_id_contrato
    into   v_fecha_inicio
      ,v_fecha_final
      ,v_variado
      ,v_cto_anterior
    from   contrato_cliente cc
    where  cc.id_contrato = p_id_contrato;
  exception
    when no_data_found then
      null;
  end;
  v_fecha_inicio_real := v_fecha_inicio;
  /*verifica si ya existe cuotas */
  begin
    select distinct c.fecha_maternidad
    into   v_fecha_maternidad
    from   cuotas_cliente cc
      ,cliente        c
    where  cc.id_contrato = p_id_contrato
    and    cc.id_cliente = p_id_cliente
    and    cc.id_secuencia = p_id_secuencia
    and    c.id_cliente = cc.id_cliente
    and    c.id_secuencia = cc.id_secuencia
    and    c.cto_clie_id_contrato = cc.id_contrato
    and    nvl(c.maternidad, 'NO') = 'SI'
    and    c.fecha_maternidad is not null
    and    trunc(cc.fecha_a_facturar, 'MM') = trunc(v_fecha_inicio, 'MM');
  exception
    when no_data_found then
      v_fecha_maternidad := null;
  end;
  if v_fecha_maternidad is not null
   and trunc(v_fecha_maternidad, 'MM') > trunc(v_fecha_inicio, 'MM') then
    v_fecha_inicio := v_fecha_maternidad;
  end if;
  select max(c.fecha_tope_cobertura)
  into   v_fecha_tope_cob
  from   cuotas_cliente c
  where  c.id_contrato = p_id_contrato
  and    c.id_cliente = p_id_cliente
  and    c.id_secuencia = p_id_secuencia
  and    c.estado = 'ACTIVO';

  delete from cuotas_cliente ccl
  where  ccl.id_cliente = p_id_cliente
  and    ccl.id_secuencia = p_id_secuencia
  and    ccl.id_contrato = p_id_contrato
  and    ccl.facturado = 'NO'
    -- cambio solicitado por alice en caso que se equivocan en inicio-fin de contrato
    --and ((trunc(ccl.fecha_a_facturar, 'mm') >= trunc(v_fecha_inicio, 'mm')
    --      and v_fecha_maternidad is  not null ) or v_fecha_maternidad is null)
  and    ccl.id_factura_prepaga is null
  and    ccl.id_factura_prepaga1 is null;

  begin
    select nvl(max(c.nro_cuota), 0)
      ,nvl(max(c.cant_cuotas), 0)
    into   v_nro_cuotas
      ,v_cant_cuotas
    from   cuotas_cliente c
    where  c.id_cliente = p_id_cliente
    and    c.id_secuencia = p_id_secuencia
    and    c.id_contrato = p_id_contrato
    and    c.estado = 'ACTIVO'
    and    c.fecha_tope_cobertura >= (select max(cc.fecha_tope_cobertura)
                  from   cuotas_cliente cc
                  where  c.id_sucursal = cc.id_sucursal
                  and    c.id_contrato = cc.id_contrato
                  and    c.id_cliente = cc.id_cliente
                  and    c.id_secuencia = cc.id_secuencia
                  and    cc.estado = 'ACTIVO'
                  and    cc.id_contrato = p_id_contrato
                  and    cc.id_cliente = p_id_cliente
                  and    cc.id_secuencia = p_id_secuencia)
    and    c.facturado = 'SI';
    if v_nro_cuotas > 0 then
      v_amplia_cuota := 'SI';
    end if;
    if v_nro_cuotas = 0 then
      begin
        select '1'
        into   dummy
        from   cuotas_cliente c
        where  c.id_cliente = p_id_cliente
        and    c.id_secuencia = p_id_secuencia
        and    c.id_contrato = p_id_contrato
        and    c.estado = 'ACTIVO'
        and    c.facturado = 'NO'
        and    c.id_factura_prepaga is null
        and    c.id_factura_prepaga1 is null
        fetch  first 1 row only;
        begin
          select max(c.nro_cuota)
          into   v_nro_cuotas
          from   cuotas_cliente   c
            ,contrato_cliente cc
          where  c.id_contrato = cc.id_contrato
          and    c.id_contrato = p_id_contrato
          and    c.id_cliente = p_id_cliente
          and    c.id_secuencia = p_id_secuencia
          and    (trunc(c.fecha_a_facturar, 'DD') between cc.fecha_inicio and cc.fecha_final or
            trunc(c.fecha_a_facturar, 'DD') < cc.fecha_inicio)
          and    c.estado = 'ACTIVO'
          and    c.facturado = 'NO'
          and    c.id_factura_prepaga is null
          and    c.id_factura_prepaga1 is null;

          v_identificador := 'SI';
          v_amplia_cuota  := 'SI';
        exception
          when no_data_found then
            v_nro_cuotas := 1;
        end;
      exception
        when no_data_found then
          null;
      end;
    end if;
  exception
    when no_data_found then
      null;
  end;
  begin
    --verificamos el estado del cliente
    select '1'
    into   dummy
    from   cliente c
    where  c.id_cliente = p_id_cliente
    and    c.id_secuencia = p_id_secuencia
    and    (c.estado_cliente = 'ACTIVO' or c.tipo_egre_id_tipo_egreso = 7)
    fetch  first 1 row only;
  exception
    when no_data_found then
      raise_application_error(-20000, 'P - Cliente se encuentra inactivo!');
  end;
  --verificamos el estado del contrato
  begin
    select distinct '1' --cc.fecha_inicio, cc.fecha_final
    into   dummy --v_fecha_inicio, v_fecha_final
    from   contrato_cliente cc
    where  cc.estado_contrato = 'ACTIVO'
    and    cc.id_contrato = p_id_contrato;
    --and trunc(p_fecha, 'dd') between cc.fecha_inicio and cc.fecha_final;  --- comentar para casos de fecha ingreso clientes antiguos, menor a hoy
  exception
    when no_data_found then
      raise_application_error(-20000,'P - El contrato ' || p_id_contrato || ' se encuentra inactivo ' ||' o fecha de ingreso del cliente incorrecta... favor verifique!');
  end;

  --buscamos el periodo de factura
  begin
    select cc.per_fact_id_periodo_factura
      ,cc.tipo_cto_id_tipo_contrato
      ,cc.emp_id_empresa
    into   v_id_periodo_factura
      ,v_tipo_contrato
      ,v_empresa
    from   contrato_cliente cc
    where  cc.id_contrato = p_id_contrato;

    select p.descripcion
      ,p.cant_cuotas
      ,meses
      ,meses
    into   v_periodo_desc
      ,v_cantidad_cuotas
      ,v_meses
      ,v_mes
    from   periodo_factura p
    where  p.id_periodo_factura = v_id_periodo_factura;
  exception
    when no_data_found then
      raise_application_error(-20000, 'P - El contrato no tiene periodo de factura!');
  end;
  --traemos la persona
  begin
    select id_persona
    into   v_id_persona
    from   persona
    where  usuario = case
         when nvl(v('APP_USER'), user) = 'SYS' then
         'ANAMNESIS'
         else
         nvl(v('APP_USER'), user)
       end;
  exception
    when no_data_found then
      raise_application_error(-20000, 'P - No existe persona! ' || nvl(v('APP_USER'), user));
  end;

  begin
    select trunc(c.fecha_ingreso, 'MM')
      ,c.fecha_ingreso
      ,c.cat_clie_id_categoria_cliente
      ,trunc((months_between(sysdate, c.fec_nac)) / 12)
      ,c.fec_nac
      ,c.minusvalido
      ,c.maternidad
      ,c.monto_cuota
      ,c.porc_sobre_uso
    into   v_fecha_ingreso
      ,v_fecha_ingreso_real
      ,v_categoria
      ,v_edad
      ,v_fecnac
      ,v_minusvalido
      ,v_maternidad
      ,v_monto_cuota_x
      ,vl_porc_sobre_uso
    from   cliente c
    where  c.id_cliente = p_id_cliente
    and    c.id_secuencia = p_id_secuencia;
  exception
    when no_data_found then
      raise_application_error(-20000, 'P - No existe cliente!');
  end;
  if nvl(v_variado, 'NO') = 'SI' then
    v_fecha_final_real1  := v_fecha_final;
    v_fecha_inicio_real1 := v_fecha_inicio;
    select e.cuota_fin_de_mes into v_cuota_fin_de_mes from emp e where e.id_empresa = v_empresa;
    if v_cuota_fin_de_mes = 'SI' then
      v_fecha_inicio := trunc(v_fecha_inicio, 'MM');
      v_fecha_final  := last_day(v_fecha_final);
    end if;
  end if;
  ---prorrateo
  -- verificar si el dia de inicio de contrato es superior al ultimo dia del ingreso
  -- del cliente
  v_dia_inic_cto := to_number(to_char(v_fecha_inicio, 'DD'));
  if v_dia_inic_cto > to_number(to_char(last_day(v_fecha_ingreso), 'DD')) then
    v_dia_inic_cto := to_number(to_char(last_day(v_fecha_ingreso), 'DD'));
  end if;

  /*if nvl(vl_porc_sobre_uso, 0) > 0
  then
    vl_aumento := vl_porc_sobre_uso;
  else
    vl_aumento := obtener_porc_aumento(v_fecha_inicio, v_empresa);
  end if;*/

  if v_tipo_contrato = 6
   and p_monto_cuota > 0
   and v_fecha_ingreso_real > v_fecha_inicio
   and (trunc(v_fecha_ingreso_real, 'MM') <> v_fecha_ingreso_real or
   (trunc(v_fecha_inicio, 'MM') <> v_fecha_inicio and
   to_date(substr('0' || to_char(v_dia_inic_cto), -2) || to_char(v_fecha_ingreso, 'MM-YYYY'), 'DD-MM-RR') <> v_fecha_ingreso_real))
   and v_categoria not in (5, 81)
   and v_empresa not in (51, 77, 91, 93, 452, 625, 627, 628, 23, 24, 1103, 1118, 1119) --,1003) --,1167) --1071,203)10) then
    --si la fecha final del contrato es el ultimo dia del mes
    if v_fecha_final = last_day(v_fecha_final) then
      v_cant_dias_mes := to_char(last_day(v_fecha_ingreso_real), 'DD');
      -- verificar si la fecha tope cobertura debe ser el fin de mes, o no
      if nvl(v_cuota_fin_de_mes, 'NO') = 'NO' then
        -- si no debe ajustarse al fin de mes, se calcula la fecha tope
        -- un mes despues del inicio del contrato.
        v_cant_dias_cob := (add_months(to_date(substr('0' || to_char(v_dia_inic_cto), -2) || to_char(v_fecha_ingreso, 'MM-YYYY')
                       ,'DD-MM-RR')
                    ,1) - 1) - v_fecha_ingreso_real + 1;
      else
        -- si debe ajustarse a fin de mes
        -- se calcula la fecha tope al final del mes en que ingreso.
        v_cant_dias_cob := last_day(v_fecha_ingreso_real) - v_fecha_ingreso_real + 1;
      end if;
    else
      -- v_cant_dias_mes := add_months(to_date(to_char(v_fecha_final,'dd')||'/'||to_char(v_fecha_inicio,'mm/yyyy')),1)- v_fecha_inicio;
      if to_char(add_months(v_fecha_inicio, 1), 'MM') = 2 then
        if to_char(v_fecha_final, 'DD') > to_char(last_day(add_months(v_fecha_inicio, 1)), 'DD') then
          v_cant_dias_mes := to_date(to_char(last_day(add_months(v_fecha_inicio, 1)), 'DD') ||
                     to_char(add_months(v_fecha_inicio, 1), 'MM-YYYY')
                    ,'DD-MM-RR') - v_fecha_inicio;
        else
          v_cant_dias_mes := to_date(to_char(v_fecha_final, 'DD') || to_char(add_months(v_fecha_inicio, 1), 'MM-YYYY'), 'DD-MM-RR') -
                  v_fecha_inicio;
        end if;
      else
        v_cant_dias_mes := to_date(to_char(v_fecha_final, 'DD') || to_char(add_months(v_fecha_inicio, 1), 'MM-YYYY'), 'DD-MM-RR') -
                (v_fecha_inicio - 1);
      end if;
      if to_char(v_fecha_ingreso, 'MM') = 2 then
        if to_char(v_fecha_inicio, 'DD') > to_char(last_day(v_fecha_ingreso), 'DD') then
          if to_date(to_char(last_day(v_fecha_ingreso), 'DD') || to_char(v_fecha_ingreso, 'MM-YYYY'), 'DD-MM-RR') >= v_fecha_ingreso_real then
            v_cant_dias_cob := to_date(to_char(last_day(v_fecha_ingreso), 'DD') || to_char(v_fecha_ingreso_real, 'MM-YYYY') ,'DD-MM-RR') - v_fecha_ingreso_real + 1;
          else
            v_cant_dias_cob := add_months(to_date(to_char(v_fecha_final, 'DD') || '/' || to_char(v_fecha_ingreso_real, 'MM/YYYY') ,'DD-MM-RR') ,1) - v_fecha_ingreso_real + 1;
          end if;
        else
          if to_date(to_char(v_fecha_inicio, 'DD') || to_char(v_fecha_ingreso, 'MM-YYYY'), 'DD-MM-RR') > v_fecha_ingreso_real then
            v_cant_dias_cob := to_date(to_char(v_fecha_final, 'DD') || to_char(v_fecha_ingreso_real, 'MM-YYYY'), 'DD-MM-RR') - v_fecha_ingreso_real + 1;
          else
            v_cant_dias_cob := add_months(to_date(to_char(v_fecha_final, 'DD') || '/' || to_char(v_fecha_ingreso_real, 'MM/YYYY') ,'DD-MM-RR') ,1) - v_fecha_ingreso_real + 1;
          end if;
        end if;
      else
        if to_date(to_char(v_fecha_inicio, 'DD') || to_char(v_fecha_ingreso, 'MM-YYYY'), 'DD-MM-RR') > v_fecha_ingreso_real then
          v_cant_dias_cob := to_date(to_char(v_fecha_final, 'DD') || to_char(v_fecha_ingreso_real, 'MM-YYYY'), 'DD-MM-RR') - v_fecha_ingreso_real + 1;
        else
          v_cant_dias_cob := add_months(to_date(to_char(v_fecha_final, 'DD') || '/' || to_char(v_fecha_ingreso_real, 'MM/YYYY') ,'DD-MM-RR') ,1) - v_fecha_ingreso_real + 1;
        end if;
      end if;
    end if;
    -- cuando el dia de ingreso es superior al dia de inicio de contrato, se averigua
    -- cuantos dias no se le cobro al cliente, en vez de contar los dias que hay
    -- entre la fecha a facturar y la fecha tope.
    if to_number(to_char(v_fecha_ingreso_real, 'DD')) > v_dia_inic_cto then
      mostrar('Descontar ' || (to_number(to_char(v_fecha_ingreso_real, 'DD')) - v_dia_inic_cto) || ' dias');
      v_cant_dias_cob := v_cant_dias_mes - (to_number(to_char(v_fecha_ingreso_real, 'DD')) - v_dia_inic_cto);
    end if;
    -- verificar si se trata de la primera cuota que se generara para este contrato
    -- porque el prorrateo solo se debe considerar para la primera cuota.
    select count(*)
    into   v_existe_cuotas
    from   cuotas_cliente cc
    where  cc.id_contrato = p_id_contrato
    and    cc.id_cliente = p_id_cliente
    and    cc.id_secuencia = p_id_secuencia;
    -- al tomar el dia de la fecha final de contrato
    -- solia dar error cuando el mes de ingreso era febrero
    -- porque al contcatenar generaba 31/02/2022 por ejemplo, lo que daba error
    if to_number(to_char(v_fecha_final, 'DD')) > 28 then
      v_calc_dias := to_number(to_char(v_fecha_final, 'DD')) - 3;
    else
      v_calc_dias := to_number(to_char(v_fecha_final, 'DD'));
    end if;
    -- si ya existe alguna cuota generada para el contrato/cliente/secuencia
    -- se debe asignar la cuota entera, no hay prorrateo.
    if v_existe_cuotas > 0
     or (add_months(v_fecha_ingreso_real, 1) - 1 < (v_fecha_final - 1)
     -- fecha tope de primera cuota
     and add_months(v_fecha_ingreso_real, 1) - 1 =
     -- fecha final de la primera cuota segun la fecha de contrato.
     add_months(to_date(v_calc_dias || '/' || to_char(v_fecha_ingreso_real, 'MM/YYYY'), 'DD-MM-RR'), 1) and
     nvl(v_cuota_fin_de_mes, 'NO') = 'NO') then
      v_monto_cuota := p_monto_cuota;
    else
      v_monto_cuota     := round((nvl(p_monto_cuota, 0) * v_cant_dias_cob) / v_cant_dias_mes);
      v_prorrateo       := 'S';
      v_prorrateo_lici  := 'SI';
      v_prorrateo_nuevo := 'SI';
    end if;
    /*05/10/2016*/
    if v_monto_cuota > p_monto_cuota then
      v_monto_cuota := p_monto_cuota;
    end if;
  elsif v_periodo_desc like 'ANUAL%'
    and round(months_between(v_fecha_final, v_fecha_ingreso)) < 12
    and v_fecha_ingreso > v_fecha_inicio
    and v_cantidad_cuotas > 0 then
    v_cantidad_cuotas_real := v_cantidad_cuotas;
    v_cant_meses           := (v_meses / v_cantidad_cuotas_real);
    if months_between(v_fecha_ingreso, v_fecha_inicio) >= v_cantidad_cuotas_real then
      v_cantidad_cuotas := 1;
    else
      v_cantidad_cuotas := v_cantidad_cuotas_real - months_between(v_fecha_ingreso, v_fecha_inicio);
    end if;
    v_monto_cuota := round(round(round(round(nvl(p_monto_cuota, 0) * v_cantidad_cuotas_real) / 12) *
                round(months_between(v_fecha_final, v_fecha_ingreso)) / v_cantidad_cuotas));
    v_prorrateo   := 'N';
    v_cant_meses  := null;
  elsif v_id_periodo_factura = 37 and round(months_between(v_fecha_final, v_fecha_inicio)) < 12 and v_cantidad_cuotas > 0 then
    v_cantidad_cuotas_real := v_cantidad_cuotas;
    v_cant_meses           := (v_meses / v_cantidad_cuotas_real);
    v_cantidad_cuotas      := months_between(v_fecha_final, v_fecha_inicio);
    v_monto_cuota          := round(round(nvl(p_monto_cuota, 0) / 12) * v_cantidad_cuotas);
    v_prorrateo            := 'N';
    v_cant_meses           := null;
    v_cantidad_cuotas      := 1;
  elsif v_id_periodo_factura in (41, 51, 52) and round(months_between(v_fecha_final, v_fecha_ingreso)) < 12 and v_fecha_ingreso > v_fecha_inicio then
    for i in 1 .. round(round(months_between(v_fecha_final, v_fecha_inicio_real)) / v_meses) loop
      if v_fecha_ingreso < add_months(v_fecha_inicio_real, v_meses * i) then
        v_monto_cuota := round(nvl(p_monto_cuota, 0) * round(months_between(add_months(v_fecha_inicio_real, v_meses * i), v_fecha_ingreso)) / v_meses);
        exit;
      elsif v_fecha_ingreso = add_months(v_fecha_inicio_real, v_meses * i) then
        v_monto_cuota := p_monto_cuota;
        exit;
      end if;
    end loop;
    v_prorrateo := 'N';
  else
    v_monto_cuota := p_monto_cuota;
    v_prorrateo   := 'N';
  end if;
  if v_identificador = 'NO' and v_amplia_cuota = 'NO' then
    if trunc(v_fecha_inicio) < trunc(v_fecha_ingreso) then
      if to_char(v_fecha_inicio, 'DD') = 31 and to_char(v_fecha_ingreso, 'MM') in (4, 6, 9, 11) then
        v_fecha_inicio := to_date((to_char(v_fecha_inicio, 'DD') - 1) || to_char(v_fecha_ingreso, 'MM-YYYY'), 'DD-MM-RR');
      elsif to_char(v_fecha_inicio, 'DD') = (29) and to_char(v_fecha_ingreso, 'MM') = 2 then
        v_fecha_inicio := to_date((to_char(v_fecha_inicio, 'DD') - 1) || to_char(v_fecha_ingreso, 'MM-YYYY'), 'DD-MM-RR');
      elsif to_char(v_fecha_inicio, 'DD') = (30) and to_char(v_fecha_ingreso, 'MM') = 2 then
        if (to_char(v_fecha_inicio, 'DD') > to_char(last_day(v_fecha_ingreso), 'DD')) then
          v_fecha_inicio := to_date((to_char(v_fecha_inicio, 'DD')) || to_char(add_months(v_fecha_ingreso, -1), 'MM-YYYY'), 'DD-MM-RR');
        else
          v_fecha_inicio := to_date((to_char(v_fecha_inicio, 'DD') - 2) || to_char(v_fecha_ingreso, 'MM-YYYY'), 'DD-MM-RR');
        end if;
      elsif to_char(v_fecha_inicio, 'DD') = (31) and to_char(v_fecha_ingreso, 'MM') = 2 then
        v_fecha_inicio := to_date((to_char(v_fecha_inicio, 'DD') - 3) || to_char(v_fecha_ingreso, 'MM-YYYY'), 'DD-MM-RR');
      else
        v_fecha_inicio       := to_date(to_char(v_fecha_inicio, 'DD') || to_char(v_fecha_ingreso, 'MM-YYYY'), 'DD-MM-RR');
        v_fecha_inicio_real1 := to_date(to_char(v_fecha_inicio, 'DD') || to_char(v_fecha_ingreso, 'MM-YYYY'), 'DD-MM-RR');
      end if;
      if v_fecha_inicio > v_fecha_ingreso_real then
        if to_char(v_fecha_inicio, 'DD') = 31 and to_char(v_fecha_ingreso_real, 'MM') in (4, 6, 9, 11) then
          v_fecha_inicio       := to_date(to_char(v_fecha_inicio, 'DD') - 1 || to_char(add_months(v_fecha_ingreso, -1), 'MM-YYYY') ,'DD-MM-RR');
          v_fecha_inicio_real1 := to_date(to_char(v_fecha_inicio, 'DD') - 1 || to_char(add_months(v_fecha_ingreso, -1), 'MM-YYYY') ,'DD-MM-RR');
        elsif to_char(v_fecha_inicio, 'DD') = (29) and to_char(v_fecha_ingreso_real, 'MM') = 2 then
          v_fecha_inicio       := to_date(to_char(v_fecha_inicio, 'DD') - 1 || to_char(add_months(v_fecha_ingreso, -1), 'MM-YYYY') ,'DD-MM-RR');
          v_fecha_inicio_real1 := to_date(to_char(v_fecha_inicio, 'DD') - 1 || to_char(add_months(v_fecha_ingreso, -1), 'MM-YYYY') ,'DD-MM-RR');
        elsif to_char(v_fecha_inicio, 'DD') = (30) and to_char(v_fecha_ingreso_real, 'MM') = 2 then
          v_fecha_inicio       := to_date(to_char(v_fecha_inicio, 'DD') - 2 || to_char(add_months(v_fecha_ingreso, -1), 'MM-YYYY') ,'DD-MM-RR');
          v_fecha_inicio_real1 := to_date(to_char(v_fecha_inicio, 'DD') - 2 || to_char(add_months(v_fecha_ingreso, -1), 'MM-YYYY') ,'DD-MM-RR');
        elsif to_char(v_fecha_inicio, 'DD') = (31) and to_char(v_fecha_ingreso_real, 'MM') = 2 then
          v_fecha_inicio       := to_date(to_char(v_fecha_inicio, 'DD') - 3 || to_char(add_months(v_fecha_ingreso, -1), 'MM-YYYY') ,'DD-MM-RR');
          v_fecha_inicio_real1 := to_date(to_char(v_fecha_inicio, 'DD') - 3 || to_char(add_months(v_fecha_ingreso, -1), 'MM-YYYY') ,'DD-MM-RR');
        else
          v_fecha_inicio       := to_date(to_char(v_fecha_inicio, 'DD') || to_char(add_months(v_fecha_ingreso, -1), 'MM-YYYY') ,'DD-MM-RR');
          v_fecha_inicio_real1 := to_date(to_char(v_fecha_inicio, 'DD') || to_char(add_months(v_fecha_ingreso, -1), 'MM-YYYY') ,'DD-MM-RR');
        end if;
      end if;
    elsif trunc(v_fecha_ingreso) > trunc(v_fecha_inicio) and v_cto_anterior is not null and v_edad = 0 then
      v_fecha_inicio       := to_date(to_char(v_fecha_inicio, 'DD') || to_char(v_fecha_ingreso, 'MM-YYYY'), 'DD-MM-RR');
      v_fecha_inicio_real1 := to_date(to_char(v_fecha_inicio, 'DD') || to_char(v_fecha_ingreso, 'MM-YYYY'), 'DD-MM-RR');
    end if;
    begin
      select nvl(min(c.nro_cuota), 1)
        ,max(c.cant_cuotas)
      into   v_nro_cuotas_n
        ,v_cantidad_cuotas_n
      from   cuotas_cliente   c
        ,contrato_cliente cc
      where  c.id_contrato = cc.id_contrato
      and    c.id_contrato = p_id_contrato
      and    c.id_cliente = p_id_cliente
      and    c.id_secuencia = p_id_secuencia
      and    trunc(c.fecha_a_facturar, 'DD') between trunc(v_fecha_inicio, 'DD') and trunc(v_fecha_final, 'DD')
      and    c.estado = 'ACTIVO';
      if v_cantidad_cuotas_n is null then
        select round(months_between(v_fecha_final, v_fecha_inicio)) into v_cantidad_cuotas_n from dual;
      end if;
      v_nro_cuotas   := 1;
      v_amplia_cuota := 'SI';
      v_nueva_cuota  := 'SI';
    exception
      when no_data_found then
        v_nro_cuotas := 1;
    end;
  end if;
  if v_cantidad_cuotas > 0 then
    if v_nro_cuotas > v_cantidad_cuotas then
      raise_application_error(-20000,'P - No se generaron las cuotas debido a que este cliente ingreso en una fecha ' || 'posterior a la ultima fecha de cuota del grupo!');
    end if;
  end if;

  if v_cantidad_cuotas > 0 then
    v_cantidad_meses := months_between(v_fecha_final, v_fecha_inicio);
    v_cantidad_anhos := (v_cantidad_meses / 12);
    if v_nro_cuotas = 0 then
      v_nro_cuotas := 1;
    end if;
    if (v_tipo_contrato = 2)
     or v_empresa in (618
            ,619
            ,620
            ,623
            ,1135
            ,1136
            ,203
            ,1157
            ,1158
            ,1159
            ,1160
            ,1085
            ,1035
            ,1172
            ,10
            ,51
            ,1178
            ,77
            ,91
            ,93
            ,452
            ,625
            ,627
            ,628
            ,23
            ,24
            ,1003
            ,1167
            ,1071
            ,1198
            ,1199
            ,1200
            ,1201
            ,1202
            ,1203
            ,1053
            ,1218) then
      --agregado desde la empresa 10 por ac 30/04/2019
      if v_empresa in (618
            ,619
            ,620
            ,623
            ,1135
            ,1136
            ,203
            ,1157
            ,1158
            ,1159
            ,1160
            ,1085
            ,1035
            ,1172
            ,10
            ,51
            ,1178
            ,77
            ,91
            ,93
            ,452
            ,625
            ,627
            ,628
            ,23
            ,24
            ,1003
            ,1167
            ,1071
            ,1198
            ,1199
            ,1200
            ,1201
            ,1202
            ,1203
            ,1053
            ,1218)
       and v_fecha_ingreso_real > v_fecha_inicio then
        v_edad := floor((v_fecha_ingreso_real - v_fecnac) / 365);
      else
        v_edad := floor((v_fecha_inicio - v_fecnac) / 365);
      end if;
      if v_edad < 0 then
        v_edad := 0;
      end if;
      v_edad2 := v_edad + 1;
      if v_tipo_contrato = 6
       and v_minusvalido = 'SI' then
        v_edad  := 10;
        v_edad2 := 10;
      end if;
      select t.plan_id_plan
        ,t.mnd_id_moneda
        ,cl.grup_beneid_grupo_beneficiario
        ,cl.cat_clie_id_categoria_cliente
        ,cl.sexo
        ,cl.porc_sobre_uso
        ,t.id_tarifa
      into   v1_plan_id_plan
        ,v1_mnd_id_moneda
        ,v1_id_grupo_beneficiario
        ,v1_id_categoria_cliente
        ,v1_sexo
        ,v1_porc_sobre_uso
        ,v1_id_tarifa
      from   cliente cl
        ,tarifa  t
      where  cl.cto_clie_id_contrato = p_id_contrato
      and    cl.id_cliente = p_id_cliente
      and    (cl.tipo_egre_id_tipo_egreso is null or cl.tipo_egre_id_tipo_egreso = 7)
      and    cl.tarifa_id_tarifa = t.id_tarifa
      and    cl.id_secuencia = p_id_secuencia;
      v_cambia_tarifa1 := 'NO';
      verifica_tarifa_2(p_tipo_cto       => v_tipo_contrato
             ,p_plan           => v1_plan_id_plan
             ,p_moneda         => v1_mnd_id_moneda
             ,p_grupo          => v1_id_grupo_beneficiario
             ,p_edad_vigencia  => v_edad
             ,p_categoria      => v1_id_categoria_cliente
             ,p_id_tarifa      => v1_id_tarifa
             ,p_id_cliente     => p_id_cliente
             ,p_id_secuencia   => p_id_secuencia
             ,p_fecha_vigencia => v_fecha_inicio
             ,p_actualizar     => 'SI'
             ,p_cambia_tarifa  => v_cambia_tarifa1
             ,p_mensaje        => v1_mensaje);
      dbms_output.put_line('calculo_cuota 1');
      calculo_cuota(p_tipo_cto       => v_tipo_contrato
           ,p_plan           => v1_plan_id_plan
           ,p_moneda         => v1_mnd_id_moneda
           ,p_grupo          => v1_id_grupo_beneficiario
           ,p_fecha_vigencia => v_fecha_inicio
           ,p_edad_vigencia  => v_edad
           ,p_categoria      => v1_id_categoria_cliente
           ,p_nrocto         => p_id_contrato
           ,p_sexo           => v1_sexo
           ,s_monto_cuota    => v_monto_cuota1
           ,s_id_tarifa      => v1_id_tarifa
           ,s_mensaje        => v1_mensaje
           ,p_porc_sobre_uso => v1_porc_sobre_uso
           ,p_form_6000      => p_form_6000
           ,p_maternidad     => v_maternidad);
      if v1_mensaje is not null then
        raise_application_error(-20000, v1_mensaje);
      end if;
      v_feccum := to_date(to_char(v_fecha_inicio, 'DD') || '/' || to_char(v_fecnac, 'MM') || '/' || to_char(v_fecha_inicio, 'YYYY')
              ,'DD/MM/RRRR');
      if v_fecha_inicio <= v_fecnac then
        v_feccum := to_date(to_char(v_fecha_inicio, 'DD') || '/' || to_char(v_fecnac, 'MM') || '/' || to_char(v_fecnac, 'YYYY')
                ,'DD/MM/RRRR');
        v_feccum := (add_months(v_feccum, 12));
      end if;
      if v_feccum < v_fecha_inicio then
        v_feccum := (add_months(v_feccum, 12));
      end if;
      v_feccum         := (add_months(v_feccum, 1) - to_number(to_char(v_fecha_inicio, 'DD')));
      v_cambia_tarifa2 := 'NO';
      if trunc(v_fecha_final) > trunc(v_feccum) then
        verifica_tarifa_2(p_tipo_cto       => v_tipo_contrato
               ,p_plan           => v1_plan_id_plan
               ,p_moneda         => v1_mnd_id_moneda
               ,p_grupo          => v1_id_grupo_beneficiario
               ,p_edad_vigencia  => v_edad2
               ,p_categoria      => v1_id_categoria_cliente
               ,p_id_tarifa      => v1_id_tarifa
               ,p_id_cliente     => p_id_cliente
               ,p_id_secuencia   => p_id_secuencia
               ,p_fecha_vigencia => last_day(v_feccum) + 1
               ,p_actualizar     => 'NO'
               ,p_cambia_tarifa  => v_cambia_tarifa2
               ,p_mensaje        => v1_mensaje);
        dbms_output.put_line('calculo_cuota 2');
        calculo_cuota(p_tipo_cto       => v_tipo_contrato
             ,p_plan           => v1_plan_id_plan
             ,p_moneda         => v1_mnd_id_moneda
             ,p_grupo          => v1_id_grupo_beneficiario
             ,p_fecha_vigencia => v_fecha_inicio
             ,p_edad_vigencia  => v_edad2
             ,p_categoria      => v1_id_categoria_cliente
             ,p_nrocto         => p_id_contrato
             ,p_sexo           => v1_sexo
             ,s_monto_cuota    => v_monto_cuota2
             ,s_id_tarifa      => v1_id_tarifa
             ,s_mensaje        => v1_mensaje
             ,p_porc_sobre_uso => v1_porc_sobre_uso
             ,p_form_6000      => p_form_6000
             ,p_maternidad     => v_maternidad);
        if v1_mensaje is not null then
          raise_application_error(-20000, v1_mensaje);
        end if;
      else
        v_monto_cuota2 := null;
      end if;
    end if;
    for i in nvl(v_nro_cuotas, 1) .. v_cantidad_cuotas loop
      if i = 1 then
        v_primera_cuota := 'SI';
      else
        v_primera_cuota  := 'NO';
        v_prorrateo_lici := 'NO';
      end if;
      if v_periodo_desc not like 'ANUAL%'
       and v_primera_cuota = 'NO' then
        v_monto_cuota := p_monto_cuota;
      end if;
      if (v_tipo_contrato = 2)
       or (v_empresa in (618
              ,619
              ,620
              ,623
              ,1135
              ,1136
              ,203
              ,1157
              ,1158
              ,1159
              ,1160
              ,1085
              ,1035
              ,1172
              ,1198
              ,1199
              ,1200
              ,1201
              ,1202
              ,1203
              ,10
              ,51
              ,1178
              ,77
              ,91
              ,93
              ,452
              ,625
              ,627
              ,628
              ,23
              ,24
              ,1003
              ,1167
              ,1071
              ,1053
              ,1218) --agregado por ac 30/09/2014 desde la empresa 10
       and v_prorrateo_nuevo = 'NO') then
        if i = 1 then
          v1_fecha_cuota := v_fecha_inicio;
        else
          v1_fecha_cuota := add_months(v_fecha_inicio, (i - 1));
        end if;
        if v_feccum < v1_fecha_cuota then
          v_monto_cuota := v_monto_cuota2;
        else
          v_monto_cuota := v_monto_cuota1;
        end if;
      end if;
      if v_primera_cuota = 'SI' then
        if i = 1 then
          begin
            select distinct nvl(t.porcentaje, c.porc_aumento)
            into   v_porc_promo
            from   cliente_renovado c
              ,tipo_promocion   t
            where  c.id_promo = t.id_promo --(+)
            and    c.id_contrato_act = p_id_contrato
            and    c.id_cliente = p_id_cliente
            and    c.id_secuencia = p_id_secuencia;
          exception
            when no_data_found then
              v_porc_promo := 1;
          end;
        else
          v_porc_promo := 1;
        end if;
        /*if v_porc_promo = 1
         and vl_aumento > 0 then
          v_porc_promo := vl_aumento;
        end if;*/
        mostrar('INSERT 1' || chr(10) || 'Porcentaje Aumento Cuota: ' || v_porc_promo);
        insert into cuotas_cliente
          (id_sucursal
          ,id_contrato
          ,id_cliente
          ,id_secuencia
          ,fecha_a_facturar
          ,nro_cuota
          ,cant_cuotas
          ,monto_cuota
          ,fecha_tope_cobertura
          ,facturado
          ,id_persona
          ,fecha_creacion
          ,estado
          ,prorrateada
          ,id_tipo_promocion
          ,porc_descuento
          ,tar_id_tarifa)
        values
          (1
          ,p_id_contrato
          ,p_id_cliente
          ,p_id_secuencia
          ,decode(i, 1, v_fecha_inicio, add_months(v_fecha_inicio, (i - 1)))
          ,i
          ,v_cantidad_cuotas
          ,decode(v_porc_promo, 1, v_monto_cuota, round(v_monto_cuota * (1 - v_porc_promo), 0))
          --,case v_porc_promo when 1 then v_monto_cuota when > 1 then round(v_monto_cuota * (1 - v_porc_promo), 0) end
          ,decode(v_primera_cuota
             ,'NO'
             ,(add_months(v_fecha_inicio, 1) - 1)
             ,(decode(i, v_cantidad_cuotas, v_fecha_final, (add_months(v_fecha_inicio, i) - 1))))
          ,'NO'
          ,v_id_persona
          ,sysdate
          ,'ACTIVO'
          ,v_prorrateo_lici
          ,null
          ,null
          ,v1_id_tarifa);
      else
        if i = 1 then
          begin
            select distinct nvl(t.porcentaje, c.porc_aumento)
            into   v_porc_promo
            from   cliente_renovado c
              ,tipo_promocion   t
            where  c.id_promo = t.id_promo --(+)
            and    c.id_contrato_act = p_id_contrato
            and    c.id_cliente = p_id_cliente
            and    c.id_secuencia = p_id_secuencia;
          exception
            when no_data_found then
              v_porc_promo := 1;
          end;
        else
          v_porc_promo := 1;
        end if;
        /*if v_porc_promo = 1
         and vl_aumento > 0 then
          v_porc_promo := vl_aumento;
        end if;*/
        mostrar('INSERT 2' || chr(10) || 'Porcentaje Aumento Cuota: ' || v_porc_promo);
        insert into cuotas_cliente
          (id_sucursal
          ,id_contrato
          ,id_cliente
          ,id_secuencia
          ,fecha_a_facturar
          ,nro_cuota
          ,cant_cuotas
          ,monto_cuota
          ,fecha_tope_cobertura
          ,facturado
          ,id_factura_prepaga
          ,id_persona
          ,fecha_creacion
          ,estado
          ,id_factura_prepaga1
          ,prorrateada
          ,monto_cuota_dif
          ,obs_cuota_dif
          ,id_tipo_promocion
          ,porc_descuento
          ,tar_id_tarifa)
        values
          (1
          ,p_id_contrato
          ,p_id_cliente
          ,p_id_secuencia
          ,decode(i, 1, v_fecha_inicio, add_months(v_fecha_inicio, (i - 1)))
          ,i
          ,v_cantidad_cuotas
          ,decode(v_porc_promo, 1, v_monto_cuota, round(v_monto_cuota * (1 - v_porc_promo), 0))
          ,decode(v_primera_cuota
             ,'SI'
             ,(add_months(v_fecha_inicio, 1) - 1)
             ,(decode(i, v_cantidad_cuotas, v_fecha_final, (add_months(v_fecha_inicio, i) - 1))))
          ,'NO'
          ,null
          ,v_id_persona
          ,sysdate
          ,'ACTIVO'
          ,null
          ,null
          ,null
          ,null
          ,null
          ,null
          ,v1_id_tarifa);
      end if;
      if i = 1
       or v_nro_cuotas = i then
        update cliente c
        set    c.fec_ult_fact = decode(i, 1, v_fecha_inicio, add_months(v_fecha_inicio, (i - 1)))
        where  c.id_cliente = p_id_cliente
        and    c.id_secuencia = p_id_secuencia
        and    v_tipo_contrato in (6, 2)
        and    c.fec_ult_fact is null;
      end if;
    end loop;

    if (v_tipo_contrato = 2)
     or v_empresa in (618
            ,619
            ,620
            ,623
            ,1135
            ,1136
            ,203
            ,1157
            ,1158
            ,1159
            ,1160
            ,1085
            ,1035
            ,1172
            ,1198
            ,1199
            ,1200
            ,1201
            ,1202
            ,1203
            ,10
            ,51
            ,1178
            ,77
            ,91
            ,93
            ,452
            ,625
            ,627
            ,628
            ,23
            ,24
            ,1003
            ,1167
            ,1071
            ,1053
            ,1218) then
      --agregado por ac el 30/04/2019 desde la empresa 10
      if v_cambia_tarifa2 = 'NO' then
        p_monto_cuota := v_monto_cuota;
      else
        p_monto_cuota := v_monto_cuota1;
      end if;
    end if;
  elsif v_cantidad_cuotas = 0 then

    if v_id_periodo_factura in (41, 51, 52)
     and v_fecha_inicio_real <> v_fecha_inicio then
      v_cantidad_meses  := months_between(v_fecha_final, v_fecha_inicio_real);
      v_cantidad_cuotas := (v_cantidad_meses / v_meses);
      for i in 1 .. v_cantidad_cuotas loop
        if v_fecha_inicio < add_months(v_fecha_inicio_real, v_meses * i) then
          if i = 1
           and v_fecha_inicio_real > add_months(v_fecha_inicio_real, - (v_meses * i)) then
            v_fecha_inicio := v_fecha_inicio_real;
          else
            v_fecha_inicio := add_months(v_fecha_inicio_real, (v_meses * (i - 1)));
          end if;
          exit;
        elsif v_fecha_inicio = add_months(v_fecha_inicio_real, v_meses * i) then
          v_fecha_inicio := add_months(v_fecha_inicio_real, v_meses * i);
          exit;
        end if;
      end loop;
    end if;

    v_cantidad_meses  := months_between(v_fecha_final, v_fecha_inicio);
    v_cantidad_cuotas := (v_cantidad_meses / v_meses);
    if v_amplia_cuota = 'SI'
     and v_nueva_cuota = 'NO' then
      if v_fecha_final > v_fecha_tope_cob then
        v_nro_cuotas_u := (v_nro_cuotas + v_cantidad_cuotas);
      end if;
      v_nro_cuotas_n := v_nro_cuotas;
      v_nro_cuotas   := 1;
      v_meses        := round(months_between(v_fecha_final, v_fecha_inicio));
      begin
        select max(cc.fecha_a_facturar)
          ,count(*)
        into   v_fecha_a_facturar
          ,v_cantidad_real
        from   cuotas_cliente cc
        where  cc.id_contrato = p_id_contrato
        and    cc.id_cliente = p_id_cliente
        and    cc.id_secuencia = p_id_secuencia;
      exception
        when no_data_found then
          v_fecha_a_facturar := null;
          v_cantidad_real    := 0;
      end;
    end if;

    if (v_tipo_contrato = 2)
     or v_empresa in (618
            ,619
            ,620
            ,623
            ,1135
            ,1136
            ,203
            ,1157
            ,1158
            ,1159
            ,1160
            ,1085
            ,1035
            ,1172
            ,1198
            ,1199
            ,1200
            ,1201
            ,1202
            ,1203
            ,10
            ,51
            ,1178
            ,77
            ,91
            ,93
            ,452
            ,625
            ,627
            ,628
            ,23
            ,24
            ,1003
            ,1167
            ,1071
            ,1053
            ,1218) then
      --agregado por ac el 30/04/2019 desde empresa 10
      if v_empresa in (618
            ,619
            ,620
            ,623
            ,1135
            ,1136
            ,203
            ,1157
            ,1158
            ,1159
            ,1160
            ,1085
            ,1035
            ,1172
            ,1198
            ,1199
            ,1200
            ,1201
            ,1202
            ,1203
            ,10
            ,51
            ,1178
            ,77
            ,91
            ,93
            ,452
            ,625
            ,627
            ,628
            ,23
            ,24
            ,1003
            ,1167
            ,1071
            ,1053
            ,1218)
       and v_fecha_ingreso_real > v_fecha_inicio then
        if months_between(v_fecha_final, v_fecha_inicio) > 12 then
          -- si el contrato supera los 12 meses se compara la edad con sysdate  -- s.a. 26/12/2022
          v_edad := floor((sysdate - v_fecnac) / 365);
        else
          -- como estaba originalmente, se compara la fecha de nacimiento con la fecha de ingreso.
          v_edad := floor((v_fecha_ingreso_real - v_fecnac) / 365); -- s.a. 31/07/2020
        end if;
      else
        --v_edad := trunc((months_between(v_fecha_inicio, v_fecnac))/12);
        v_edad := floor((v_fecha_inicio - v_fecnac) / 365); -- s.a. 31/07/2020
      end if;
      if v_edad < 0 then
        v_edad := 0;
      end if;
      v_edad2 := v_edad + 1;
      --v_edad2 := v_edad; -- s.a. 31/07/2020
      if v_tipo_contrato = 6
       and v_minusvalido = 'SI' then
        v_edad  := 10;
        v_edad2 := 10;
      end if;

      select t.plan_id_plan
        ,t.mnd_id_moneda
        ,cl.grup_beneid_grupo_beneficiario
        ,cl.cat_clie_id_categoria_cliente
        ,cl.sexo
        ,cl.porc_sobre_uso
        ,t.id_tarifa
      into   v1_plan_id_plan
        ,v1_mnd_id_moneda
        ,v1_id_grupo_beneficiario
        ,v1_id_categoria_cliente
        ,v1_sexo
        ,v1_porc_sobre_uso
        ,v1_id_tarifa
      from   cliente cl
        ,tarifa  t
      where  cl.cto_clie_id_contrato = p_id_contrato
      and    cl.id_cliente = p_id_cliente
      and    (cl.tipo_egre_id_tipo_egreso is null or cl.tipo_egre_id_tipo_egreso = 7)
      and    cl.tarifa_id_tarifa = t.id_tarifa
      and    cl.id_secuencia = p_id_secuencia;
      v_cambia_tarifa1 := 'NO';
      begin
        select distinct 1
        into   dummy
        from   detalle_tarifa d
        where  d.id_tarifa = v1_id_tarifa
        and    v_edad between d.edad_ini and d.edad_fin;
      exception
        when no_data_found then
          v_edad := v_edad2;
      end;

      verifica_tarifa_2(p_tipo_cto       => v_tipo_contrato
             ,p_plan           => v1_plan_id_plan
             ,p_moneda         => v1_mnd_id_moneda
             ,p_grupo          => v1_id_grupo_beneficiario
             ,p_edad_vigencia  => v_edad
             ,p_categoria      => v1_id_categoria_cliente
             ,p_id_tarifa      => v1_id_tarifa
             ,p_id_cliente     => p_id_cliente
             ,p_id_secuencia   => p_id_secuencia
             ,p_fecha_vigencia => v_fecha_inicio
             ,p_actualizar     => 'SI'
             ,p_cambia_tarifa  => v_cambia_tarifa1
             ,p_mensaje        => v1_mensaje);

      dbms_output.put_line('calculo_cuota 3');

      calculo_cuota(p_tipo_cto       => v_tipo_contrato
           ,p_plan           => v1_plan_id_plan
           ,p_moneda         => v1_mnd_id_moneda
           ,p_grupo          => v1_id_grupo_beneficiario
           ,p_fecha_vigencia => v_fecha_inicio
           ,p_edad_vigencia  => v_edad
           ,p_categoria      => v1_id_categoria_cliente
           ,p_nrocto         => p_id_contrato
           ,p_sexo           => v1_sexo
           ,s_monto_cuota    => v_monto_cuota1
           ,s_id_tarifa      => v1_id_tarifa
           ,s_mensaje        => v1_mensaje
           ,p_porc_sobre_uso => v1_porc_sobre_uso
           ,p_form_6000      => p_form_6000
           ,p_maternidad     => v_maternidad);

      /*IF UserEnv('TERMINAL')='SCSAINFO2022' THEN
       --if v1_mensaje is null then
       raise_application_Error(-20000,'PUNTO DE CONTROL');
       --END IF;
      END IF;*/

      if v1_mensaje is not null then
        raise_application_error(-20000, v1_mensaje);
      end if;

      v_feccum := to_date(to_char(v_fecha_inicio, 'DD') || '/' || to_char(v_fecnac, 'MM') || '/' || to_char(v_fecha_inicio, 'YYYY')
              ,'DD/MM/RRRR');
      if v_fecha_inicio <= v_fecnac then
        v_feccum := to_date(to_char(v_fecha_inicio, 'DD') || '/' || to_char(v_fecnac, 'MM') || '/' || to_char(v_fecnac, 'YYYY')
                ,'DD/MM/RRRR');
        v_feccum := (add_months(v_feccum, 12));
      end if;

      if v_feccum <= v_fecha_inicio then
        v_feccum := (add_months(v_feccum, 12));
      end if;
      v_feccum         := (add_months(v_feccum, 1) - to_number(to_char(v_fecha_inicio, 'DD')));
      v_cambia_tarifa2 := 'NO';

      if trunc(v_fecha_final) > trunc(v_feccum) then
        mostrar('V_FECHA_FINAL: ' || v_fecha_final || ' V_FECCUM:' || trunc(v_feccum));
        verifica_tarifa_2(p_tipo_cto       => v_tipo_contrato
               ,p_plan           => v1_plan_id_plan
               ,p_moneda         => v1_mnd_id_moneda
               ,p_grupo          => v1_id_grupo_beneficiario
               ,p_edad_vigencia  => v_edad2
               ,p_categoria      => v1_id_categoria_cliente
               ,p_id_tarifa      => v1_id_tarifa
               ,p_id_cliente     => p_id_cliente
               ,p_id_secuencia   => p_id_secuencia
               ,p_fecha_vigencia => last_day(v_feccum) + 1
               ,p_actualizar     => 'NO'
               ,p_cambia_tarifa  => v_cambia_tarifa2
               ,p_mensaje        => v1_mensaje);

        dbms_output.put_line('calculo_cuota 4');

        calculo_cuota(p_tipo_cto       => v_tipo_contrato
             ,p_plan           => v1_plan_id_plan
             ,p_moneda         => v1_mnd_id_moneda
             ,p_grupo          => v1_id_grupo_beneficiario
             ,p_fecha_vigencia => v_fecha_inicio
             ,p_edad_vigencia  => v_edad2
             ,p_categoria      => v1_id_categoria_cliente
             ,p_nrocto         => p_id_contrato
             ,p_sexo           => v1_sexo
             ,s_monto_cuota    => v_monto_cuota2
             ,s_id_tarifa      => v1_id_tarifa
             ,s_mensaje        => v1_mensaje
             ,p_porc_sobre_uso => v1_porc_sobre_uso
             ,p_form_6000      => p_form_6000
             ,p_maternidad     => v_maternidad);
        if v1_mensaje is not null then
          raise_application_error(-20000, v1_mensaje);
        end if;
      else
        v_monto_cuota2 := null;
      end if;
    end if;
    for i in nvl(v_nro_cuotas, 1) .. v_cantidad_cuotas loop
      if nvl(v_variado, 'NO') = 'SI'
       and p_monto_cuota > 0
       and (i = 1 or i = v_cantidad_cuotas) then
        if i = 1
         and trunc(v_fecha_inicio_real1, 'MM') <> v_fecha_inicio_real1
         and v_prorrateo = 'N' then
          v_monto_cuota     := round((nvl(p_monto_cuota, 0) * v_cant_dias_cob) / v_cant_dias_mes);
          v_prorrateo_nuevo := 'SI';
        elsif i = v_cantidad_cuotas
          and last_day(v_fecha_final_real1) <> v_fecha_final_real1 then
          v_monto_cuota     := round((nvl(p_monto_cuota, 0) * to_char(v_fecha_final_real1, 'DD')) /
                     to_char(last_day(v_fecha_final_real1), 'DD'));
          v_prorrateo_nuevo := 'SI';
        elsif i = 1 then
          v_monto_cuota := v_monto_cuota;
        else
          v_monto_cuota := p_monto_cuota;
        end if;
        if v_prorrateo = 'S'
         and v_fecha_inicio > v_fecha_inicio_real1 then
          v_fecha_inicio_real1 := null;
        end if;
      elsif i <> 1
        and i = v_cantidad_cuotas
        and nvl(v_variado, 'NO') = 'NO' then
        v_monto_cuota := p_monto_cuota;
      end if;
      if v_amplia_cuota = 'NO' then
        if i > 1 then
          v_prorrateo_lici := 'NO';
          v_cant_meses     := (v_meses * (i - 1));
        else
          v_cant_meses := v_meses;
        end if;
        if i = 1 then
          v_fecha_cuota := nvl(v_fecha_inicio_real1, v_fecha_inicio);
        elsif i = v_cantidad_cuotas then
          v_fecha_cuota := add_months(v_fecha_final + 1, -v_meses);
        else
          if v_fecha_inicio = last_day(v_fecha_inicio)
           and v_fecha_final <> last_day(v_fecha_final) then
            v_fecha_cuota := add_months(v_fecha_inicio - 1, v_cant_meses) + 1;
          else
            v_fecha_cuota := add_months(v_fecha_inicio, v_cant_meses);
          end if;
        end if;
        ------fecha tope -----
        if i = v_cantidad_cuotas then
          v_fecha_tope := nvl(v_fecha_final_real1, v_fecha_final);
        elsif i = 1 then
          v_fecha_tope := (add_months(v_fecha_inicio, v_meses) - 1);
        else
          v_fecha_tope := add_months(v_fecha_inicio - 1, (v_cant_meses + v_meses));
        end if;
        if i = v_cantidad_cuotas
         and to_char(v_fecha_cuota, 'MM') <> to_char(v_fecha_tope, 'MM')
         and nvl(v_variado, 'NO') = 'SI' then
          if ((v_fecha_tope - v_fecha_cuota) + 1 >= 30)
           or (((v_fecha_tope - v_fecha_cuota) + 1 >= 28) and to_char(v_fecha_cuota, 'MM') = 2) then
            v_prorrateo_nuevo := 'NO';
          else
            v_monto_cuota     := round((nvl(p_monto_cuota, 0) * (v_fecha_tope - v_fecha_cuota) + 1) /
                       to_char(last_day(v_fecha_final_real1), 'DD'));
            v_prorrateo_nuevo := 'SI';
          end if;
        end if;
        if (v_tipo_contrato = 2)
         or (v_empresa in (618
                ,619
                ,620
                ,623
                ,1135
                ,1136
                ,203
                ,1157
                ,1158
                ,1159
                ,1160
                ,1085
                ,1035
                ,1172
                ,1198
                ,1199
                ,1200
                ,1201
                ,1202
                ,1203
                ,10
                ,51
                ,1178
                ,77
                ,91
                ,93
                ,452
                ,625
                ,627
                ,628
                ,23
                ,24
                ,1003
                ,1167
                ,1071
                ,1053
                ,1218) --agregado por ac el 30/04/2019 desde empresa 10
         and v_prorrateo_nuevo = 'NO') then
          if i = 1 then
            v1_fecha_cuota := v_fecha_inicio;
          else
            v1_fecha_cuota := add_months(v_fecha_inicio, (i - 1));
          end if;
          if v_feccum < v1_fecha_cuota then
            v_monto_cuota := v_monto_cuota2;
            x_monto_cuota := v_monto_cuota2;
          else
            v_monto_cuota := v_monto_cuota1;
            x_monto_cuota := v_monto_cuota1;
          end if;
        end if;
        if v_fecha_cuota > v_fecha_a_facturar
         or v_fecha_a_facturar is null then
          if i = 1 then
            begin
              select distinct nvl(t.porcentaje, c.porc_aumento)
              into   v_porc_promo
              from   cliente_renovado c
                ,tipo_promocion   t
              where  c.id_promo = t.id_promo --(+)
              and    c.id_contrato_act = p_id_contrato
              and    c.id_cliente = p_id_cliente
              and    c.id_secuencia = p_id_secuencia;
            exception
              when no_data_found then
                v_porc_promo := 1;
            end;
          else
            v_porc_promo := 1;
          end if;
          /*if v_porc_promo = 1
           and vl_aumento > 0 then
            v_porc_promo := vl_aumento;
          end if;*/
          mostrar('INSERT 3' || chr(10) || 'Porcentaje Aumento Cuota: ' || v_porc_promo || chr(10) || 'Nro Cuota: ' || i);
          --javier
          insert into cuotas_cliente
            (id_sucursal
            ,id_contrato
            ,id_cliente
            ,id_secuencia
            ,fecha_a_facturar
            ,nro_cuota
            ,cant_cuotas
            ,monto_cuota
            ,fecha_tope_cobertura
            ,facturado
            ,id_factura_prepaga
            ,id_persona
            ,fecha_creacion
            ,estado
            ,id_factura_prepaga1
            ,prorrateada
            ,monto_cuota_dif
            ,obs_cuota_dif
            ,id_tipo_promocion
            ,porc_descuento
            ,tar_id_tarifa)
          values
            (1
            ,p_id_contrato
            ,p_id_cliente
            ,p_id_secuencia
            ,v_fecha_cuota
            ,decode(v_fecha_inicio, v_fecha_inicio_real, i, i + nvl(v_cantidad_real, 0))
            ,v_cantidad_cuotas
            ,decode(nvl(v_prorrateo_nuevo, 'NO')
               ,'SI'
               ,decode(v_porc_promo, 1, v_monto_cuota, round(v_monto_cuota * (1 - v_porc_promo), 0))
               ,decode(v_porc_promo, 1, x_monto_cuota, round(x_monto_cuota * (1 - v_porc_promo), 0)))
            ,v_fecha_tope
            ,'NO'
            ,null
            ,v_id_persona
            ,sysdate
            ,'ACTIVO'
            ,null
            ,v_prorrateo_lici
            ,null
            ,null
            ,null
            ,null
            ,v1_id_tarifa);
          v_prorrateo_nuevo := 'NO';
          if i = 1
           or v_nro_cuotas = i then
            update cliente c
            set    c.fec_ult_fact = decode(i
                        ,1
                        ,v_fecha_inicio
                        ,(decode(i
                           ,v_cantidad_cuotas
                           ,add_months(v_fecha_final + 1, -v_meses)
                           ,add_months(v_fecha_inicio, v_cant_meses))))
            where  c.id_cliente = p_id_cliente
            and    c.id_secuencia = p_id_secuencia
            and    v_tipo_contrato in (6, 2)
            and    c.fec_ult_fact is null;
          end if;
        end if;
        if v_fecha_ingreso_real < v_fecha_a_facturar then
          v_prorrateo_nuevo := 'NO';
        end if;
      elsif v_amplia_cuota = 'SI' then
        if i = 1 then
          v_fecha_cuota := nvl(v_fecha_inicio_real1, v_fecha_inicio);
        else
          v_prorrateo_lici := 'NO';
          if v_fecha_inicio = last_day(v_fecha_inicio)
           and v_fecha_final <> last_day(v_fecha_final) then
            v_fecha_cuota := add_months(v_fecha_inicio - 1, (i - 1) * v_mes) + 1;
          else
            v_fecha_cuota := add_months(v_fecha_inicio, (i - 1) * v_mes);
          end if;
        end if;
        ------fecha tope -----
        if i = v_cantidad_cuotas then
          v_fecha_tope := nvl(v_fecha_final_real1, v_fecha_final);
        elsif i = 1 then
          v_fecha_tope := (add_months(v_fecha_inicio, v_mes) - 1);
        else
          ---
          v_fecha_tope := add_months((v_fecha_inicio - 1), i * v_mes);
        end if;
        if i = v_cantidad_cuotas then
          if to_char(v_fecha_cuota, 'MM') <> to_char(v_fecha_tope, 'MM') then
            if nvl(v_variado, 'NO') = 'SI' then
              if ((v_fecha_tope - v_fecha_cuota) + 1 >= 30)
               and to_char(v_fecha_cuota, 'MM') in (4, 6, 9, 11)
               or (((v_fecha_tope - v_fecha_cuota) + 1 >= 28) and to_char(v_fecha_cuota, 'MM') = 2) then
                v_prorrateo_nuevo := 'NO';
              else
                v_monto_cuota     := round(nvl(p_monto_cuota, 0) * ((v_fecha_tope - v_fecha_cuota) + 1) /
                           to_char(last_day(v_fecha_final_real1), 'DD'));
                v_prorrateo_nuevo := 'SI';
              end if;
            end if;
          else
            -- para la ultima cuota, cuando el inicio y fin de la cuota estan en el mismo mes.
            -- dbms_output.put_line('mismo mes para inicio y fin de cuota '||(v_fecha_tope-v_fecha_cuota));
            -- null; -- si el inicio y fin de la cuota cae en el mismo mes, verificar si se debe prorratear.
            v_monto_cuota := round(nvl(p_monto_cuota, 0) * ((v_fecha_tope - v_fecha_cuota) + 1) /
                     to_char(last_day(v_fecha_tope), 'DD'));
            x_monto_cuota := round(nvl(p_monto_cuota, 0) * ((v_fecha_tope - v_fecha_cuota) + 1) /
                     to_char(last_day(v_fecha_tope), 'DD'));
          end if;
        end if;
        if (v_tipo_contrato = 2)
         or (v_empresa in (618
                ,619
                ,620
                ,623
                ,1135
                ,1136
                ,203
                ,1157
                ,1158
                ,1159
                ,1160
                ,1085
                ,1035
                ,1172
                ,1198
                ,1199
                ,1200
                ,1201
                ,1202
                ,1203
                ,10
                ,51
                ,1178
                ,77
                ,91
                ,93
                ,452
                ,625
                ,627
                ,628
                ,23
                ,24
                ,1003
                ,1167
                ,1071
                ,1053
                ,1218) --agregado por ac el 30/04/2019 desde empresa 10
         and v_prorrateo_nuevo = 'NO') then
          if i = 1 then
            v1_fecha_cuota := v_fecha_inicio;
          else
            v1_fecha_cuota := add_months(v_fecha_inicio, (i - 1));
          end if;
          if v_feccum < v1_fecha_cuota then
            v_monto_cuota := v_monto_cuota2;
            x_monto_cuota := v_monto_cuota2;
          else
            v_monto_cuota := v_monto_cuota1;
            x_monto_cuota := v_monto_cuota1;
          end if;
          mostrar('--V_FECCUM: ' || v_feccum || chr(10) || '--V1_FECHA_CUOTA: ' || v1_fecha_cuota || chr(10) || '--V_MONTO_CUOTA: ' ||
             v_monto_cuota || chr(10) || '--X_MONTO_CUOTA: ' || x_monto_cuota || chr(10) || '--V_MONTO_CUOTA2: ' ||
             v_monto_cuota2 || chr(10) || '--V_MONTO_CUOTA1: ' || v_monto_cuota1);
        end if;

        mostrar('***---Prorrateo: ' || v_variado || chr(10) || 'Fecha Cuota: ' || v_fecha_cuota || chr(10) || 'Fecha a Facturar: ' ||
           v_fecha_a_facturar || chr(10) || '***---Fecha hasta: ' || v_fecha_tope || chr(10) || 'SUMADO 1 MES ' ||
           (add_months(v_fecha_cuota, 1) - 1) || chr(10) || 'INICIO REAL:' || v_fecha_inicio_real);

        if v_fecha_cuota > v_fecha_a_facturar
         or v_fecha_a_facturar is null then
          if i = 1 then
            begin
              select distinct nvl(t.porcentaje, c.porc_aumento)
                    ,c.id_promo
              into   v_porc_promo
                ,v_id_promo
              from   cliente_renovado c
                ,tipo_promocion   t
              where  c.id_promo = t.id_promo --(+)
              and    c.id_contrato_act = p_id_contrato
              and    c.id_cliente = p_id_cliente
              and    c.id_secuencia = p_id_secuencia;
            exception
              when no_data_found then
                v_porc_promo := 1;
                mostrar('No Encontre Promo' || chr(10) || 'Porcentaje Aumento Cuota: ' || v_porc_promo || chr(10) ||
                   'Nro Cuota: ' || i);
            end;
          else
            v_porc_promo := 1;
            mostrar('Apete: ' || v_fecha_cuota || ' > ' || v_fecha_a_facturar || chr(10) || 'Porcentaje Aumento Cuota: ' ||
               v_porc_promo || chr(10) || 'Nro Cuota: ' || i);
          end if;
          if i = v_cantidad_cuotas
           and v_empresa = 635
           and x_monto_cuota > 0 then
            x_monto_cuota := x_monto_cuota + round((x_monto_cuota / to_char(last_day(v_fecha_tope), 'DD')), 0);
          end if;
          select decode(nvl(v_prorrateo_nuevo, 'NO')
               ,'SI'
               ,decode(v_porc_promo, 1, v_monto_cuota, round(v_monto_cuota * (1 - v_porc_promo), 0))
               ,decode(v_porc_promo, 1, x_monto_cuota, round(x_monto_cuota * (1 - v_porc_promo), 0)))
          into   v_mostrar
          from   dual;
          mostrar(v_mostrar || ' - PRORRATEO NUEVO: ' || v_prorrateo_nuevo || ' - PRORRATEO LICI: ' || v_prorrateo_lici ||
             ' - fecha_desde: ' || v_fecha_cuota || ' - fecha hasta:' || v_fecha_tope || ' - SUMADO 1 MES ' ||
             (add_months(v_fecha_cuota, 1) - 1) || ' - INICIO REAL:' || v_fecha_inicio_real || ' - V_EDAD: ' || v_edad ||
             ' - V_EDAD2: ' || v_edad2 || chr(10) || 'Porcentaje Aumento Cuota: ' || v_porc_promo || chr(10) ||
             '***--- Monto Cuota: ' || x_monto_cuota);

          mostrar('INSERT 4' || chr(10) || 'Porcentaje Aumento Cuota: ' || v_porc_promo || chr(10) || 'Nro Cuota: ' || i);
          -- obtener datos de numero de cuotas
          select decode(v_fecha_inicio, v_fecha_inicio_real, i, i + nvl(v_cantidad_real, 0)) into v_nro_cuo_insert from dual;
          select decode(v_fecha_maternidad
               ,v_fecha_inicio
               ,decode(v_nro_cuotas_u, 0, v_cantidad_cuotas, v_nro_cuotas_u)
               ,v_cantidad_cuotas)
          into   v_total_cuo_insert
          from   dual;
          -- verificar cuantos dias trae el mes en el cual inicia la cuota
          select
          -- si la fecha a facturar y la fecha tome son en el mismo mes....
          case
            when trunc(decode(v_nro_cuo_insert, 1, v_fecha_ingreso_real, v_fecha_cuota), 'MM') = trunc(v_fecha_tope, 'MM') then
            -- toma la cantidad de dias que trae el mes en el cual esta la cuota
             to_number(to_char(last_day(v_fecha_tope), 'DD'), '99')
            else -- si la fecha a facturar y fecha tope no estan en el mismo mes...
            -- se toma la cantidad de dias que trae el mes en el que esta la fecha_a_facturar
             to_number(to_char(last_day(decode(v_nro_cuo_insert, 1, v_fecha_ingreso_real, v_fecha_cuota)), 'DD'), '99')
          end
          into   v_dias_mes
          from   dual;
          /*  siendo licitacion, con costo y no completa 1 mes, se debe prorratear */
          if (v_tipo_contrato = 6 and v_monto_cuota = p_monto_cuota)
           and (
           -- para primera y ultima cuota
            ((((trunc(v_fecha_tope) - trunc(v_fecha_cuota) + 1) < v_dias_mes /*30*/
            and v_nro_cuo_insert > 1) or ((trunc(v_fecha_tope) - trunc(v_fecha_ingreso_real) + 1) < v_dias_mes /*30*/
            and v_nro_cuo_insert = 1)) and (v_nro_cuo_insert = v_total_cuo_insert -- ultima cuota
            or v_nro_cuo_insert = 1 -- primera cuota
            )) or -- para cualquier cuota
            ((trunc(v_fecha_tope) - trunc(v_fecha_ingreso_real) + 1) < v_dias_mes --30
            )

           ) then
            -- cantidad de dias para dividir la cuota
            v_cant_dias_mes := trunc(last_day(v_fecha_tope)) - trunc(v_fecha_tope, 'MM') + 1;
            --cantidad de dias de inicio y fin de cuota.
            if v_nro_cuo_insert = 1 -- primera cuota
             or (trunc(v_fecha_tope) - trunc(v_fecha_ingreso_real) + 1) < v_dias_mes --30 -- o cualquier cuota incorporacion then
              v_cant_dias_cob := (trunc(v_fecha_tope) - trunc(v_fecha_ingreso_real) + 1);
              x_monto_cuota   := round((v_monto_cuota) / v_cant_dias_mes * v_cant_dias_cob);
              v_monto_cuota   := round((v_monto_cuota) / v_cant_dias_mes * v_cant_dias_cob);
            else
              v_cant_dias_cob := (trunc(v_fecha_tope) - trunc(v_fecha_cuota) + 1);
              x_monto_cuota   := round((v_monto_cuota) / v_cant_dias_mes * v_cant_dias_cob);
              v_monto_cuota   := round((v_monto_cuota) / v_cant_dias_mes * v_cant_dias_cob);
            end if;
            mostrar('**** V_CANT_DIAS_COB: ' || v_cant_dias_cob || chr(10) || '**** V_FECHA_TOPE: ' || v_fecha_tope || chr(10) ||
               '**** V_FECHA_INGRESO_REAL: ' || v_fecha_ingreso_real || chr(10) || '**** v_monto_cuota: ' || v_monto_cuota ||
               chr(10) || '**** x_monto_cuota: ' || x_monto_cuota || chr(10) || '**** V_FECHA_TOPE: ' || v_fecha_tope ||
               chr(10) || '**** V_FECHA_CUOTA: ' || v_fecha_cuota);
          end if;

          if v_tipo_contrato = 6 then
            --recuperar monto cuota segun edad en la fecha de cuota
            begin
              select distinct t.id_tarifa
                    ,dt.prima_basica
              into   v1_id_tarifa
                ,x_monto_cuota
              from   cliente        c
                ,tarifa         t
                ,detalle_tarifa dt
              where  c.tarifa_id_tarifa = t.id_tarifa
              and    dt.id_tarifa = t.id_tarifa
              and    c.id_cliente = p_id_cliente
              and    c.id_secuencia = p_id_secuencia
              and    c.cto_clie_id_contrato = p_id_contrato
              and    v_fecha_cuota between dt.fecha_ini and dt.fecha_fin
              and    floor((months_between(v_fecha_cuota, c.fec_nac)) / 12) between dt.edad_ini and dt.edad_fin
              --and    c.monto_cuota != 0 --s.a. 29/12/2023 (correo diana grupo beneficiario con costo cero, el sistema genera cuota con costo. 29/12/2023 09:13)
              ;

              if v_monto_cuota_x = 0 then
                x_monto_cuota := v_monto_cuota_x;
              else
                v_monto_cuota := x_monto_cuota;
              end if;

              mostrar('*-*- Fecha Cuota: ' || v_fecha_cuota || chr(10) || '*-*- Id Tarifa : ' || v_fecha_a_facturar || chr(10) ||
                 '*-*- Monto Cuota: ' || x_monto_cuota);

              /*  siendo licitacion, con costo y no completa 1 mes, se debe prorratear */
              if (v_tipo_contrato = 6 and v_monto_cuota = p_monto_cuota)
               and (
               -- para primera y ultima cuota
                ((((trunc(v_fecha_tope) - trunc(v_fecha_cuota) + 1) < v_dias_mes /*30*/
                and v_nro_cuo_insert > 1) or ((trunc(v_fecha_tope) - trunc(v_fecha_ingreso_real) + 1) < v_dias_mes /*30*/
                and v_nro_cuo_insert = 1)) and (v_nro_cuo_insert = v_total_cuo_insert -- ultima cuota
                or v_nro_cuo_insert = 1 -- primera cuota
                )) or -- para cualquier cuota
                ((trunc(v_fecha_tope) - trunc(v_fecha_ingreso_real) + 1) < v_dias_mes --30
                )

               ) then
                -- cantidad de dias para dividir la cuota
                v_cant_dias_mes := trunc(last_day(v_fecha_tope)) - trunc(v_fecha_tope, 'MM') + 1;
                --cantidad de dias de inicio y fin de cuota.
                if v_nro_cuo_insert = 1 -- primera cuota
                 or (trunc(v_fecha_tope) - trunc(v_fecha_ingreso_real) + 1) < v_dias_mes --30 -- o cualquier cuota incorporacion then
                  v_cant_dias_cob := (trunc(v_fecha_tope) - trunc(v_fecha_ingreso_real) + 1);
                  x_monto_cuota   := round((v_monto_cuota) / v_cant_dias_mes * v_cant_dias_cob);
                  v_monto_cuota   := round((v_monto_cuota) / v_cant_dias_mes * v_cant_dias_cob);
                else
                  v_cant_dias_cob := (trunc(v_fecha_tope) - trunc(v_fecha_cuota) + 1);
                  x_monto_cuota   := round((v_monto_cuota) / v_cant_dias_mes * v_cant_dias_cob);
                  v_monto_cuota   := round((v_monto_cuota) / v_cant_dias_mes * v_cant_dias_cob);
                end if;
                mostrar('**** V_CANT_DIAS_COB: ' || v_cant_dias_cob || chr(10) || '**** V_FECHA_TOPE: ' || v_fecha_tope ||
                   chr(10) || '**** V_FECHA_INGRESO_REAL: ' || v_fecha_ingreso_real || chr(10) ||
                   '**** v_monto_cuota: ' || v_monto_cuota || chr(10) || '**** x_monto_cuota: ' || x_monto_cuota ||
                   chr(10) || '**** V_FECHA_TOPE: ' || v_fecha_tope || chr(10) || '**** V_FECHA_CUOTA: ' ||
                   v_fecha_cuota);
              end if;

            exception
              when no_data_found then
                --p_mensaje := 'no se encontro la tarifa para el cliente...' || chr(10) || 'trace: ' || dbms_utility.format_error_backtrace;
                --return;
                null;
                --raise_application_error(-20099, 'no se encontro la tarifa para el cliente...' || chr(10) || 'trace: ' || dbms_utility.format_error_backtrace);

            end;
          end if;
          /*if v_porc_promo = 1
           and vl_aumento > 0 then
            v_porc_promo := vl_aumento;
          end if;*/
          mostrar('*-*- Tipo Contrato: ' || v_tipo_contrato || chr(10) || '*-*- Porc. Aumento: ' || v_porc_promo || chr(10) ||
             '*-*- Monto Cuota:' || x_monto_cuota || chr(10) || '*-*- Calculo Cuota: ' || case when
             NVL(v_prorrateo_nuevo, 'NO') = 'SI' then case when v_porc_promo = 1 then v_monto_cuota else
             ROUND(v_monto_cuota * (1 - v_porc_promo), 0) end else case when v_porc_promo = 1 then x_monto_cuota else
             ROUND(x_monto_cuota * (1 - v_porc_promo), 0) end
             end || chr(10) || '*-*- Calculo Cuota 2: ' || round(p_monto_cuota * ((vl_aumento / 100) + 1)));
          insert into cuotas_cliente
            (id_sucursal
            ,id_contrato
            ,id_cliente
            ,id_secuencia
            ,fecha_a_facturar
            ,nro_cuota
            ,cant_cuotas
            ,monto_cuota
            ,fecha_tope_cobertura
            ,facturado
            ,id_factura_prepaga
            ,id_persona
            ,fecha_creacion
            ,estado
            ,id_factura_prepaga1
            ,prorrateada
            ,monto_cuota_dif
            ,obs_cuota_dif
            ,id_tipo_promocion
            ,porc_descuento
            ,tar_id_tarifa)
          values
            (1
            ,p_id_contrato
            ,p_id_cliente
            ,p_id_secuencia
            ,v_fecha_cuota
            ,v_nro_cuo_insert
            ,v_total_cuo_insert
            ,decode(nvl(v_prorrateo_nuevo, 'NO')
               ,'SI'
               ,decode(v_porc_promo, 1, v_monto_cuota, round(v_monto_cuota * (1 - v_porc_promo), 0))
               ,decode(v_porc_promo, 1, x_monto_cuota, round(x_monto_cuota * (1 - v_porc_promo), 0)))
            ,v_fecha_tope
            ,'NO'
            ,null
            ,v_id_persona
            ,sysdate
            ,'ACTIVO'
            ,null
            ,v_prorrateo_lici
            ,null
            ,null
            ,null
            ,null
            ,v1_id_tarifa);
          v_prorrateo_nuevo := 'NO';
          if i = 1
           or v_nro_cuotas = i then
            if v_control_camb_plan = 'S' then
              update cliente c
              set    c.fec_ult_fact = decode(i
                          ,1
                          ,v_fecha_inicio
                          ,(decode(i
                             ,v_cantidad_cuotas
                             ,add_months(v_fecha_final + 1, -v_meses)
                             ,add_months(v_fecha_inicio, v_cant_meses))))
              where  c.id_cliente = p_id_cliente
              and    c.id_secuencia = p_id_secuencia
              and    v_tipo_contrato in (6, 2)
              and    c.fec_ult_fact is null;
            else
              update cliente c
              set    c.fec_ult_fact = decode(i
                          ,1
                          ,v_fecha_inicio
                          ,(decode(i
                             ,v_cantidad_cuotas
                             ,add_months(v_fecha_final + 1, -v_meses)
                             ,add_months(v_fecha_inicio, v_cant_meses))))
              where  c.id_cliente = p_id_cliente
              and    c.id_secuencia = p_id_secuencia
              and    v_tipo_contrato in (6, 2)
              and    c.fec_ult_fact is null;
            end if;
          end if;
        end if;
        if v_fecha_ingreso_real < v_fecha_a_facturar then
          v_prorrateo_nuevo := 'NO';
        end if;
      end if;
    end loop;
    if (v_tipo_contrato = 2)
     or v_empresa in (618
            ,619
            ,620
            ,623
            ,1135
            ,1136
            ,203
            ,1157
            ,1158
            ,1159
            ,1160
            ,1085
            ,1035
            ,1172
            ,1198
            ,1199
            ,1200
            ,1201
            ,1202
            ,1203
            ,10
            ,51
            ,1178
            ,77
            ,91
            ,93
            ,452
            ,625
            ,627
            ,628
            ,23
            ,24
            ,1003
            ,1167
            ,1071
            ,1053
            ,1218) then
      -- agregado por ac el 30/04/2019 desde empresa 10
      if v_cambia_tarifa2 = 'NO' then
        p_monto_cuota := v_monto_cuota;
      else
        p_monto_cuota := v_monto_cuota1;
      end if;
    end if;
  end if;

  /*
    iaro insfran - 21/06/2022
    aplicar la promocion si posee esta secuencia
  */
  declare
  begin
    --obtener el id y porcentaje de la promo desde la secuencia en cuestion
    select tp.id_promo
      ,tp.porcentaje
      ,tp.cuota_desde
      ,tp.cuota_hasta
      ,cc.fecha_inicio
    into   v_id_promo
      ,v_promo_porcentaje
      ,v_promo_cuota_desde
      ,v_promo_cuota_hasta
      ,v_fecha_inicio_contrato
    from   tipo_promocion tp
    join   cliente c
    on     c.id_cliente = p_id_cliente
    and    c.id_secuencia = p_id_secuencia
    and    c.cto_clie_id_contrato = p_id_contrato
    and    c.id_promo = tp.id_promo
    join   contrato_cliente cc
    on     cc.id_contrato = c.cto_clie_id_contrato;

    update cuotas_cliente cc
    set    cc.id_tipo_promocion = v_id_promo
      ,cc.porc_descuento    = v_promo_porcentaje
    where  cc.id_contrato = p_id_contrato
    and    cc.id_cliente = p_id_cliente
    and    cc.id_secuencia = p_id_secuencia
    and    cc.facturado = 'NO'
    and    cc.fecha_a_facturar >= v_fecha_inicio_contrato
    and    ((v_promo_cuota_desde is null or (v_promo_cuota_desde is not null and cc.nro_cuota >= v_promo_cuota_desde)) and
      (v_promo_cuota_hasta is null or (v_promo_cuota_hasta is not null and cc.nro_cuota <= v_promo_cuota_hasta)))
    and    exists (select 1
       from   cliente          c
          ,contrato_cliente cto
       where  cto.id_contrato = c.cto_clie_id_contrato
       and    cto.id_contrato = p_id_contrato
       and    c.id_cliente = p_id_cliente
       and    c.id_secuencia = p_id_secuencia
       and    trunc(c.fecha_ingreso) = trunc(cto.fecha_inicio));
  exception
    when no_data_found then
      null;
    when too_many_rows then
      raise_application_error(-20000, 'P - Se encontro mas de un registro de promociones. Favor verificar.');
    when others then
      raise_application_error(-20000, 'P - No se ha logrado establecer las promociones a las cuotas generadas.');
  end;
  if p_grabar -- and userenv('terminal') !='scinfo_02' then
    commit;
    grabar_parametros('GENERAR CUOTAS:' || ' ID_CONTRATO: ' || p_id_contrato || ' ID_CLIENTE: ' || p_id_cliente || ' ID_SECUENCIA: ' ||
           p_id_secuencia || ' FECHA: ' || p_fecha || ' MONTO_CUOTA: ' || p_monto_cuota || ' MENSAJE: ' || p_mensaje);
    p_mensaje := 'Cuotas generadas con exito!';
  end if;
exception
  when others then
    p_mensaje := 'Error: ' || sqlerrm || chr(10) || 'Trace: ' || dbms_utility.format_error_backtrace;
    raise_application_error(-20000, p_mensaje);
end;
/

GRANT EXECUTE ON generar_cuotas_cliente TO auditoria;
GRANT EXECUTE ON generar_cuotas_cliente TO britanico;
GRANT EXECUTE ON generar_cuotas_cliente TO marketing;
GRANT EXECUTE ON generar_cuotas_cliente TO r_abonados;
GRANT EXECUTE ON generar_cuotas_cliente TO r_agente_sab;
GRANT EXECUTE ON generar_cuotas_cliente TO r_analista_reportes;
GRANT EXECUTE ON generar_cuotas_cliente TO r_asesoria_juridica;
GRANT EXECUTE ON generar_cuotas_cliente TO r_auditor_prepaga;
GRANT EXECUTE ON generar_cuotas_cliente TO r_autoriza_consultas;
GRANT EXECUTE ON generar_cuotas_cliente TO r_auxiliar_contable;
GRANT EXECUTE ON generar_cuotas_cliente TO r_auxiliar_tramite;
GRANT EXECUTE ON generar_cuotas_cliente TO r_caja_prepaga;
GRANT EXECUTE ON generar_cuotas_cliente TO r_cobertura;
GRANT EXECUTE ON generar_cuotas_cliente TO r_cobranzas_prepaga;
GRANT EXECUTE ON generar_cuotas_cliente TO r_consulta_cobr_prepaga;
GRANT EXECUTE ON generar_cuotas_cliente TO r_consulta_ctacte;
GRANT EXECUTE ON generar_cuotas_cliente TO r_contabilidad;
GRANT EXECUTE ON generar_cuotas_cliente TO r_coordinacion_gerencias;
GRANT EXECUTE ON generar_cuotas_cliente TO r_debito_prepaga;
GRANT EXECUTE ON generar_cuotas_cliente TO r_direccion_medica;
GRANT EXECUTE ON generar_cuotas_cliente TO r_ejecutivo_licitaciones;
GRANT EXECUTE ON generar_cuotas_cliente TO r_facturacion_prepaga;
GRANT EXECUTE ON generar_cuotas_cliente TO r_gerente_comercial;
GRANT EXECUTE ON generar_cuotas_cliente TO r_gerente_direccion_medica;
GRANT EXECUTE ON generar_cuotas_cliente TO r_gerente_financiero;
GRANT EXECUTE ON generar_cuotas_cliente TO r_gerente_gdp;
GRANT EXECUTE ON generar_cuotas_cliente TO r_guia_medica;
GRANT EXECUTE ON generar_cuotas_cliente TO r_informatica;
GRANT EXECUTE ON generar_cuotas_cliente TO r_jefe_compras;
GRANT EXECUTE ON generar_cuotas_cliente TO r_jefe_facturacion_prep;
GRANT EXECUTE ON generar_cuotas_cliente TO r_jefe_sab;
GRANT EXECUTE ON generar_cuotas_cliente TO r_jefe_visaciones;
GRANT EXECUTE ON generar_cuotas_cliente TO r_licitaciones;
GRANT EXECUTE ON generar_cuotas_cliente TO r_liquidacion_prestador;
GRANT EXECUTE ON generar_cuotas_cliente TO r_mantenimiento_prepaga;
GRANT EXECUTE ON generar_cuotas_cliente TO r_recepcion;
GRANT EXECUTE ON generar_cuotas_cliente TO r_reclamos;
GRANT EXECUTE ON generar_cuotas_cliente TO r_rrhh;
GRANT EXECUTE ON generar_cuotas_cliente TO r_tesoreria_prepaga;
GRANT EXECUTE ON generar_cuotas_cliente TO r_tramites;
GRANT EXECUTE ON generar_cuotas_cliente TO r_ventas;
GRANT EXECUTE ON generar_cuotas_cliente TO r_visaciones;
GRANT EXECUTE ON generar_cuotas_cliente TO r_visacion_excepcional;
