create or replace function UDO_F_GET_LIST_ITEM
(
  sLIST           in varchar2,
  nITEM_NUMBER    in number,
  sDELIM          in varchar2 default ' ',
  nTO_END_STR     in number default 0
)
return varchar2
deterministic
as
  nITEM_POSITION  binary_integer;
  nITEM_LENGTH    binary_integer;
  sITEM           PKG_STD.tSTRING;
begin
  nITEM_POSITION := instr(sDELIM||sLIST, sDELIM, 1, nITEM_NUMBER);
  nITEM_LENGTH := instr(sLIST||sDELIM, sDELIM, 1, nITEM_NUMBER) - nITEM_POSITION;

  sITEM := substr(sLIST, nITEM_POSITION, nITEM_LENGTH);

  if nTO_END_STR = 1 and sITEM is not null then
    sITEM := substr(sLIST, nITEM_POSITION);
  end if;

  return sITEM;
end;
/
show errors;

create or replace function UDO_F_LIST_ITEM_COUNT
(
  sLIST           in varchar2,
  sDELIM          in varchar2 default ' '
)
return number
deterministic
as
  nITEM_COUNT     binary_integer := 0;
begin
  while instr(sLIST||sDELIM, sDELIM, 1, nITEM_COUNT + 1) != 0 loop
    nITEM_COUNT := nITEM_COUNT + 1;
  end loop;
  return nITEM_COUNT;
end;
/
show errors;

create or replace function UDO_F_S2N
(
  sNUMBER         in varchar2           -- строка с числом
)
return number deterministic -- null в случае ошибки преобразования
as
  nRESULT                      number;
  sNUMBER_                     PKG_STD.tSTRING := replace(substr(trim(sNUMBER), 1, 40), ' ', '');
begin
  begin
    nRESULT := to_number(replace(sNUMBER_, ',', '.'));
  exception
    when others then
      begin
        nRESULT := to_number(replace(sNUMBER_, '.', ','));
      exception
        when others then
          null;
      end;
  end;
  return nRESULT;
end;
/
show errors;

create or replace function UDO_F_S2D
-- Преобразование строки в дату
(
  sDATE           in varchar2
)
return date deterministic
as
  sDATE_          PKG_STD.tSTRING := trim(replace(sDATE, ',', '.'));
  nDAY            binary_integer;
  nMONTH          binary_integer;
  nYEAR           binary_integer;
  dDATE           date;
  sMONTH          PKG_STD.tSTRING;
  sYEAR           PKG_STD.tSTRING;

begin
  if sDATE is null then
    return null;
  end if;

  sDATE_ := replace(sDATE_, 'г');

  -- DD.MM.
  if length(sDATE_) >= 8 and substr(sDATE_, 3, 1) = '.' and substr(sDATE_, 6, 1) = '.' then
    -- DD.MM.YYYY
    if length(sDATE_) >= 10 then
      if substr(sDATE_, -1) = '.' then
        sDATE_ := substr(sDATE_, 1, length(sDATE_) - 1);
      end if;

      nDAY   := UDO_F_S2N(substr(sDATE_, 1, 2));
      nMONTH := UDO_F_S2N(substr(sDATE_, 4, 2));
      nYEAR  := UDO_F_S2N(substr(sDATE_, 7, 4));
    -- DD.MM.YY
    elsif length(sDATE_) = 8 then
      nDAY   := UDO_F_S2N(substr(sDATE_, 1, 2));
      nMONTH := UDO_F_S2N(substr(sDATE_, 4, 2));
      nYEAR  := UDO_F_S2N(substr(sDATE_, 7, 2));
    end if;

  -- YYYY
  elsif length(sDATE_) <= 4 then
    nDAY   := 1;
    nMONTH := 1;
    nYEAR  := UDO_F_S2N(sDATE_);

  -- MONTH YYYY
  else
    nDAY   := 1;
    sMONTH := lower(UDO_F_GET_LIST_ITEM(sDATE, 1));
    sYEAR  := UDO_F_GET_LIST_ITEM(sDATE, 2);

    if sMONTH = 'январь' then
      nMONTH := 1;
    elsif sMONTH = 'февраль' then
      nMONTH := 2;
    elsif sMONTH = 'март' then
      nMONTH := 3;
    elsif sMONTH = 'апрель' then
      nMONTH := 4;
    elsif sMONTH = 'май' then
      nMONTH := 5;
    elsif sMONTH = 'июнь' then
      nMONTH := 6;
    elsif sMONTH = 'июль' then
      nMONTH := 7;
    elsif sMONTH = 'август' then
      nMONTH := 8;
    elsif sMONTH = 'сентябрь' then
      nMONTH := 9;
    elsif sMONTH = 'октябрь' then
      nMONTH := 10;
    elsif sMONTH = 'ноябрь' then
      nMONTH := 11;
    elsif sMONTH = 'декабрь' then
      nMONTH := 12;
    end if;

    nYEAR  := UDO_F_S2N(sYEAR);
  end if;

  -- YY -> YYYY
  if nYEAR < 20 then
    nYEAR := nYEAR + 2000;
  elsif nYEAR < 100 then
    nYEAR := nYEAR + 1900;
  end if;

  begin
    dDATE := int2date(nDAY, nMONTH, nYEAR);
  exception
    when OTHERS then
      begin
        dDATE := int2date(nMONTH, nDAY, nYEAR);
      exception
        when OTHERS then
          dDATE := null;
      end;
  end;

  return dDATE;
end;
/
show errors;

create or replace function UDO_F_SLSCHEDULE_MNEMOCODE
(
  nRN             in number             -- RN графика работ
)
return varchar2
as
  sMNEMOCODE      PKG_STD.tSTRING;
  type tWEEK_DAYS is varray(7) of varchar2(2);
  aWEEK_DAYS      tWEEK_DAYS := tWEEK_DAYS('пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс');
begin
  -- Группировка по количеству часов
  for cur in
  (
    select H.HOURS_RATE
      from SLSTRSCHEDULE D,
           SLSCHEDDATE H
     where D.PRN = nRN
       and D.RN = H.PRN
       and H.HOURS_RATE > 0
     group by H.HOURS_RATE
     order by H.HOURS_RATE
  )
  loop
    -- Группировка по дням недели
    for days in
    (
      select D.DAY_NUMBER
        from SLSTRSCHEDULE D,
             SLSCHEDDATE H
       where D.PRN = nRN
         and D.RN = H.PRN
         and H.HOURS_RATE = cur.HOURS_RATE
       group by D.DAY_NUMBER
       order by D.DAY_NUMBER
    )
    loop
      sMNEMOCODE := sMNEMOCODE||aWEEK_DAYS(days.DAY_NUMBER)||',';
    end loop;
    sMNEMOCODE := substr(sMNEMOCODE, 1, length(sMNEMOCODE) - 1)||' '||cur.HOURS_RATE||';';
  end loop;

  return substr(sMNEMOCODE, 1, length(sMNEMOCODE) - 1)||'ч';
end;
/
show errors;

create or replace procedure UDO_P_PSORGGRP_LOAD
-- Загрузка табеля посещаемости группы из CSV файла
(
  nCOMPANY        in number,            -- Организация
  nIDENT          in number,            -- Идентификатор ведомости
  sMESSAGE        out varchar2          -- Результат
)
as
  cDATA           clob;
  nOFFSET         binary_integer := 1;
  sLINE           varchar2(32767);
  nCLOB_LENGTH    binary_integer;
  sLINE_LENGTH    binary_integer;
  nLINE_NUMBER    binary_integer := 0;
  dPERIOD         date;
  sAGNFAMILYNAME  PKG_STD.tSTRING;
  sAGNFIRSTNAME   PKG_STD.tSTRING;
  SAGNLASTNAME    PKG_STD.tSTRING;
  dAGNBURN        date;
  sPHONE          PKG_STD.tSTRING;
  sPHONE2         PKG_STD.tSTRING;
  dDATE_FROM      date;
  dDATE_TO        date;
  dPERIOD_BEGIN   date;
  nORG_RN         PKG_STD.tREF;
  nGROUP_RN       PKG_STD.tREF;
  nOPTION_RN      PKG_STD.tREF;
  nPAYCARD_RN     PKG_STD.tREF;
  nERROR_COUNT    binary_integer := 0;
  nLOAD_COUNT     binary_integer := 0;
  nDAYS_IN_MONTH  binary_integer;
  nMONTH          binary_integer;
  nYEAR           binary_integer;
  nHOURSTYPE      PKG_STD.tREF;
  sHOURSTYPE      PKG_STD.tSTRING;
  nBGN            binary_integer;
  nEND            binary_integer;
  sHOLIDAYS       PKG_STD.tSTRING;
  dDATE           date;
  nPAYCARDDAY     PKG_STD.tREF;
  nPAYCARDHOUR    PKG_STD.tREF;
  nWORKEDHOURS    PKG_STD.tSUMM;
  nHOURS_FACT     PKG_STD.tSUMM;
  sORG_CODE       PKG_STD.tSTRING;
  sORG_INN        PKG_STD.tSTRING;
  sGROUP_CODE     PKG_STD.tSTRING;
  sPERION         PKG_STD.tSTRING;

begin
  -- Тип часа
  begin
    select T.RN,
           T.CODE
      into nHOURSTYPE,
           sHOURSTYPE
      from SL_HOURS_TYPES T
     where T.BASE_SIGN = 1
       and substr(upper(T.SHORT_CODE), 1, 1) = 'Д';
  exception
    when NO_DATA_FOUND then
      P_EXCEPTION(0, 'Основной тип часа с кодом Д не найден.');
  end;

  -- Загрузка файла из буфера
  begin
    select B.DATA
      into cDATA
      from FILE_BUFFER B
     where B.IDENT = nIDENT;
  exception
    when NO_DATA_FOUND then
      P_EXCEPTION(0, 'Должен быть загружен CSV файл в файловый буфер.');
    when TOO_MANY_ROWS then
      P_EXCEPTION(0, 'Должен быть загружен только один CSV файл в файловый буфер.');
  end;

  -- Обработка файла
  nCLOB_LENGTH := length(cDATA);
  while nOFFSET <= nCLOB_LENGTH loop
    sLINE_LENGTH := instr(cDATA, chr(10), nOFFSET) - nOFFSET;
    if sLINE_LENGTH < 0 then
      sLINE_LENGTH := nCLOB_LENGTH + 1 - nOFFSET;
    end if;
    sLINE := substr(cDATA, nOFFSET, sLINE_LENGTH);
    nLINE_NUMBER := nLINE_NUMBER + 1;

    -- Текущий период
    if nLINE_NUMBER = 1 then
      sPERION := UDO_F_GET_LIST_ITEM(sLINE, 1, ';');
      dPERIOD := UDO_F_S2D(sPERION);
      dPERIOD_BEGIN  := trunc(dPERIOD, 'month');
      nDAYS_IN_MONTH := extract(day from last_day(dPERIOD));
      nMONTH         := extract(month from dPERIOD);
      nYEAR          := extract(year from dPERIOD);
      P_OPTIONS_SET('ParentPayCards_CalcPeriod', null, nCOMPANY, null, null, null, dPERIOD_BEGIN, 1, nOPTION_RN);

    -- Организация
    elsif nLINE_NUMBER = 2 then
      sORG_CODE      := UDO_F_GET_LIST_ITEM(sLINE, 1, ';');
      sORG_INN       := UDO_F_GET_LIST_ITEM(sLINE, 2, ';');

      begin
        select O.RN
          into nORG_RN
          from PSORG O
         where O.COMPANY = nCOMPANY
           and O.CODE = sORG_CODE;
      exception
        when NO_DATA_FOUND then
          P_EXCEPTION(0, 'Организация "%s" не найдена.', sORG_CODE);
      end;

    -- Группа
    elsif nLINE_NUMBER = 3 then
      sGROUP_CODE    := UDO_F_GET_LIST_ITEM(sLINE, 1, ';');

      begin
        select G.RN
          into nGROUP_RN
          from PSORGGRP G
         where G.PRN = nORG_RN
           and G.CODE = sGROUP_CODE;
      exception
        when NO_DATA_FOUND then
          P_EXCEPTION(0, 'Группа "%s" не найдена.', sGROUP_CODE);
      end;

      -- Проверка прав доступа
      P_PSTSBRD_GET
      (
        nCOMPANY   => nCOMPANY,   -- Организация
        nRN        => nGROUP_RN,  -- RN группы
        nCALCYEAR  => nYEAR,      -- Год расчетного периода
        nCALCMONTH => nMONTH,     -- Месяц расчетного периода
        sHOURTYPE  => sHOURSTYPE, -- Тип часа
        nBGN       => nBGN,       -- Номер первого дня табеля
        nEND       => nEND,       -- Номер последнего дня табеля
        sHOLIDAYS  => sHOLIDAYS   -- Матрица выходных/праздничных дней
      );

    -- Посещаемость персоны в группе
    elsif nLINE_NUMBER > 4 and trim(sLINE) is not null then
      sAGNFAMILYNAME := UDO_F_GET_LIST_ITEM(sLINE, 1, ';');
      sAGNFIRSTNAME  := UDO_F_GET_LIST_ITEM(sLINE, 2, ';');
      SAGNLASTNAME   := UDO_F_GET_LIST_ITEM(sLINE, 3, ';');
      dAGNBURN       := UDO_F_S2D(UDO_F_GET_LIST_ITEM(sLINE, 4, ';'));
      sPHONE         := UDO_F_GET_LIST_ITEM(sLINE, 5, ';');
      sPHONE2        := UDO_F_GET_LIST_ITEM(sLINE, 6, ';');
      dDATE_FROM     := UDO_F_S2D(UDO_F_GET_LIST_ITEM(sLINE, 7, ';'));
      dDATE_TO       := UDO_F_S2D(UDO_F_GET_LIST_ITEM(sLINE, 8, ';'));

      -- Поиск расчётной карточки
      begin
        select PC.RN
          into nPAYCARD_RN
          from PSPAYCARD PC,
               PSPERSCARD C,
               AGNLIST A
         where PC.PSORGGRP = nGROUP_RN
           and PC.DATE_FROM <= last_day(dPERIOD)
           and (PC.DATE_TO is null or PC.DATE_TO >= dPERIOD_BEGIN)
           and PC.PERSCARD = C.RN
           and C.AGENT = A.RN
           and A.AGNFAMILYNAME = sAGNFAMILYNAME
           and A.AGNFIRSTNAME = sAGNFIRSTNAME
           and cmp_vc2(A.AGNLASTNAME, SAGNLASTNAME) = 1
           and cmp_dat(A.AGNBURN, dAGNBURN) = 1;
      exception
        when NO_DATA_FOUND then
          nERROR_COUNT := nERROR_COUNT + 1;
          sMESSAGE := sMESSAGE||FORMAT_TEXT('%s. %s %s %s %s не найдена.'||chr(10),
            nERROR_COUNT, sAGNFAMILYNAME, sAGNFIRSTNAME, nvl(SAGNLASTNAME, '(без отчества)'),
            nvl(dAGNBURN, '(без даты рождения)'));
          continue;
      end;

      -- Посещаемость по дням
      for d in 1 .. nDAYS_IN_MONTH loop
        nHOURS_FACT := nvl(UDO_F_S2N(UDO_F_GET_LIST_ITEM(sLINE, 8 + d, ';')), 0);
        dDATE := int2date(d, nMONTH, nYEAR);

        if nHOURS_FACT > 0 then
          nPAYCARDDAY := PKG_PSPAYCARDTIME.CREATE_DAY(nCOMPANY, nPAYCARD_RN, dDATE);
          begin
            select H.RN,
                   H.WORKEDHOURS
              into nPAYCARDHOUR,
                   nWORKEDHOURS
              from PSPAYCARDHOUR H
             where H.PRN = nPAYCARDDAY
               and H.HOURSTYPE = nHOURSTYPE;

            if nWORKEDHOURS != nHOURS_FACT then
              update PSPAYCARDHOUR H
                 set H.WORKEDHOURS = nHOURS_FACT
               where H.PRN = nPAYCARDDAY
                 and H.HOURSTYPE = nHOURSTYPE;
            end if;
          exception
            when NO_DATA_FOUND then
              P_PSPAYCARDHOUR_BASE_INSERT
              (
                nCOMPANY     => nCOMPANY,     -- Организация
                nPRN         => nPAYCARDDAY,  -- RN дня
                nHOURSTYPE   => nHOURSTYPE,   -- Тип часа
                nWORKEDHOURS => nHOURS_FACT,  -- Количество часов
                nRN          => nPAYCARDHOUR  -- RN часа
              );
          end;
        else
          delete
            from PSPAYCARDDAY D
           where D.PRN = nPAYCARD_RN
             and D.WORKDATE = dDATE;
        end if;
      end loop;
      nLOAD_COUNT := nLOAD_COUNT + 1;
    end if;

    nOFFSET := nOFFSET + sLINE_LENGTH + 1;
  end loop;

  sMESSAGE := FORMAT_TEXT('Загружено детей: %s', nLOAD_COUNT);
end;
/
show errors;

create or replace procedure UDO_P_PSORGGRP_UNLOAD
-- Выгрузка табеля посещаемости группы в CSV файл
(
  nIDENT          in number
)
as
  dPERIOD         date := GET_OPTIONS_DATE('ParentPayCards_CalcPeriod');
  nDAYS_IN_MONTH  binary_integer := extract(day from last_day(dPERIOD));
  nMONTH          binary_integer := extract(month from dPERIOD);
  nYEAR           binary_integer := extract(year from dPERIOD);
  sPERIOD         PKG_STD.tSTRING := upper(F_GET_MONTH(nMONTH))||' '||nYEAR;
  cDATA           clob;
  sTEXT           PKG_STD.tSTRING;
  sFILENAME       PKG_STD.tSTRING;
  nCOUNT          binary_integer;
  CR              varchar2(1) := chr(10);
  nWORKEDHOURS    PKG_STD.tSUMM;
begin
  -- Создание буфера
  DBMS_LOB.CREATETEMPORARY(cDATA, true);

  -- Проверка количества отмеченных групп
  select count(*)
    into nCOUNT
    from SELECTLIST SL
   where SL.IDENT = nIDENT;

  if nCOUNT != 1 then
    P_EXCEPTION(0, 'Должна быть отмечена одна группа.');
  end if;

  -- Период, организация и группа
  for cur in
  (
    select O.CODE ORG_CODE,
           A.AGNIDNUMB,
           G.CODE GROUP_CODE,
           UDO_F_SLSCHEDULE_MNEMOCODE(G.SHEDULE) SLSCHEDULE_CODE,
           decode(lower(K.CODE), 'ясли', 1, 2) MEALS,
           G.RN GROUP_RN
      from SELECTLIST SL,
           PSORGGRP G,
           PSORG O,
           AGNLIST A,
           PSGRPKND K
     where SL.IDENT = nIDENT
       and SL.DOCUMENT = G.RN
       and G.PRN = O.RN
       and O.AGENT = A.RN
       and G.GROUPKND = K.RN
  )
  loop
    -- Заголовок
    sFILENAME := replace(cur.GROUP_CODE, ' ', '_')||'.csv';
    sTEXT := sPERIOD||';'||CR||
             cur.ORG_CODE||';'||cur.AGNIDNUMB||';'||CR||
             cur.GROUP_CODE||';'||cur.SLSCHEDULE_CODE||';'||cur.MEALS||';'||CR;
    DBMS_LOB.WRITEAPPEND(cDATA, length(sTEXT), sTEXT);
    sTEXT := 'Фамилия;Имя;Отчество;Дата рождения;Телефон 1;Телефон 2;Дата поступления;Дата выбытия;';
    for d in 1..nDAYS_IN_MONTH loop
      sTEXT := sTEXT||d||';';
    end loop;
    sTEXT := sTEXT||CR;
    DBMS_LOB.WRITEAPPEND(cDATA, length(sTEXT), sTEXT);

    -- Табель посещаемости
    for card in
    (
      select A1.AGNFAMILYNAME,
             A1.AGNFIRSTNAME,
             A1.AGNLASTNAME,
             to_char(A1.AGNBURN, 'dd.mm.yyyy') AGNBURN,
             nvl(A1.PHONE, A2.PHONE) PHONE,
             nvl(A1.PHONE2, A2.PHONE2) PHONE2,
             to_char(PC.DATE_FROM, 'dd.mm.yyyy') DATE_FROM,
             to_char(PC.DATE_TO, 'dd.mm.yyyy') DATE_TO,
             PC.RN PAYCARD_RN
        from PSPAYCARD PC,
             PSPERSCARD C,
             AGNLIST A1,
             AGNLIST A2
       where PC.PSORGGRP = cur.GROUP_RN
         and PC.DATE_FROM <= last_day(dPERIOD)
         and (PC.DATE_TO is null or PC.DATE_TO >= trunc(dPERIOD, 'month'))
         and PC.PERSCARD = C.RN
         and C.AGENT = A1.RN
         and C.PAYER = A2.RN(+)
       order by
             A1.AGNFAMILYNAME,
             A1.AGNFIRSTNAME,
             A1.AGNLASTNAME,
             A1.AGNBURN
    )
    loop
      -- Персона в группе
      sTEXT := card.AGNFAMILYNAME||';'||card.AGNFIRSTNAME||';'||card.AGNLASTNAME||';'||card.AGNBURN||';'||
               card.PHONE||';'||card.PHONE2||';'||card.DATE_FROM||';'||card.DATE_TO||';';

      -- Посещаемость по дням
      for d in 1 .. nDAYS_IN_MONTH loop
        begin
          select H.WORKEDHOURS
            into nWORKEDHOURS
            from PSPAYCARDDAY D,
                 PSPAYCARDHOUR H,
                 SL_HOURS_TYPES T
           where D.PRN = card.PAYCARD_RN
             and D.WORKDATE = int2date(d, nMONTH, nYEAR)
             and D.RN = H.PRN
             and H.HOURSTYPE = T.RN
             and T.BASE_SIGN = 1
             and substr(upper(T.SHORT_CODE), 1, 1) = 'Д';
          sTEXT := sTEXT||nWORKEDHOURS;
        exception
          when NO_DATA_FOUND then
            null;
        end;
        sTEXT := sTEXT||';';
      end loop;
      sTEXT := sTEXT||CR;
      DBMS_LOB.WRITEAPPEND(cDATA, length(sTEXT), sTEXT);
    end loop;
  end loop;

  -- Запись буфера
  P_FILE_BUFFER_INSERT(nIDENT, sFILENAME, cDATA, null);

  -- Освобождение буфера
  DBMS_LOB.FREETEMPORARY(cDATA);
end;
/
show errors;