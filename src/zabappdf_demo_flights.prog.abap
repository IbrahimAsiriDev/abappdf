REPORT zabappdf_demo_flights.

* abapPDF demo: flight passenger manifest.
* Reads the SAP flight model (SCARR, SPFLI, SFLIGHT, SBOOK), renders the manifest
* with ZCL_PDF_API (native engine), then downloads it and/or sends it as an
* e-mail attachment.
* Language: English prints form ZPDF_FLIGHT_MANIFEST, Arabic prints the right-to-left
*         form ZPDF_FLIGHT_MANIFEST_AR with Arabic class and currency names.
*         Both forms are installed by the first start of ZABAPPDF_STANDALONE on an empty
*         form store; they can also be imported in the designer from forms/*.xml.
* P_FORM: another designer form (optional). A form that does not exist falls back to
*         the English template built into this report.
* Tags: {{CARRIER_ID}} {{CARRIER_NAME}} {{CONNID}} {{CITYFROM}} {{CITYTO}} {{AIRPFROM}}
*       {{AIRPTO}} {{FLIGHT_DATE}} {{DEPTIME}} {{ARRTIME}} {{PLANETYPE}} {{SEATS}}
*       {{PRICE}} {{CURRENCY}} {{PRINTED_AT}} {{SOURCE}}
*       {{#each BOOKINGS}}{{ROW}} {{BOOKID}} {{CUSTOMID}} {{PASSNAME}} {{CLASS}}
*       {{ORDER_DATE}} {{AMOUNT}} {{CURRENCY}}{{/each}} {{count BOOKINGS}} {{sum BOOKINGS.AMOUNT}}
* If the flight tables are empty, run report SAPBC_DATA_GENERATOR to fill them;
* until then the report prints sample data.
* E-mail needs SAPconnect (SCOT); check the result in SOST.

PARAMETERS p_carr TYPE s_carr_id DEFAULT 'LH' OBLIGATORY.
PARAMETERS p_conn TYPE s_conn_id.
PARAMETERS p_max TYPE i DEFAULT 40.
SELECTION-SCREEN SKIP.
PARAMETERS p_en RADIOBUTTON GROUP lang DEFAULT 'X'.
PARAMETERS p_ar RADIOBUTTON GROUP lang.
PARAMETERS p_form TYPE c LENGTH 30.
SELECTION-SCREEN SKIP.
PARAMETERS p_down AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_mail AS CHECKBOX.
PARAMETERS p_to TYPE ad_smtpadr LOWER CASE.

CLASS lcl_demo DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_booking,
        bookid     TYPE string,
        customid   TYPE string,
        passname   TYPE string,
        class      TYPE string,
        amount     TYPE string,
        currency   TYPE string,
        order_date TYPE string,
      END OF ty_booking,
      ty_bookings TYPE STANDARD TABLE OF ty_booking WITH EMPTY KEY,
      BEGIN OF ty_doc,
        carrier_id   TYPE string,
        carrier_name TYPE string,
        connid       TYPE string,
        cityfrom     TYPE string,
        cityto       TYPE string,
        airpfrom     TYPE string,
        airpto       TYPE string,
        flight_date  TYPE string,
        deptime      TYPE string,
        arrtime      TYPE string,
        planetype    TYPE string,
        seats        TYPE string,
        price        TYPE string,
        currency     TYPE string,
        printed_at   TYPE string,
        source       TYPE string,
        bookings     TYPE ty_bookings,
      END OF ty_doc.

    METHODS run.

  PRIVATE SECTION.
    DATA ms_doc TYPE ty_doc.
    DATA mv_arabic TYPE abap_bool.

    METHODS read_flight
      RETURNING VALUE(rv_found) TYPE abap_bool.
    METHODS sample_flight.
    METHODS class_text
      IMPORTING iv_class       TYPE s_class
      RETURNING VALUE(rv_text) TYPE string.
    METHODS currency_text
      IMPORTING iv_currency    TYPE csequence
      RETURNING VALUE(rv_text) TYPE string.
    METHODS template
      RETURNING VALUE(rv_html) TYPE string.
    METHODS css
      RETURNING VALUE(rv_css) TYPE string.
    METHODS footer
      RETURNING VALUE(rv_html) TYPE string.
    METHODS file_name
      RETURNING VALUE(rv_name) TYPE string.
    METHODS send_mail
      IMPORTING iv_pdf TYPE xstring
      RAISING   cx_bcs.
ENDCLASS.

CLASS lcl_demo IMPLEMENTATION.

  METHOD run.
    DATA ls_page TYPE zcl_pdf_renderer=>ty_page.
    DATA lv_pdf TYPE xstring.

    mv_arabic = p_ar.
    IF read_flight( ) = abap_false.
      sample_flight( ).
      WRITE: / 'Note      : no booked flight found for', p_carr, '- sample data is printed.',
             / '            Run report SAPBC_DATA_GENERATOR to fill the flight tables.'.
    ENDIF.
    ms_doc-printed_at = |{ sy-datum DATE = USER } { sy-uzeit(2) }:{ sy-uzeit+2(2) }|.

    ls_page-page_size = 'A4'.
    ls_page-orientation = 'P'.
    ls_page-margin_top = 15.
    ls_page-margin_right = 12.
    ls_page-margin_bottom = 18.
    ls_page-margin_left = 12.

    DATA(lv_form) = CONV string( p_form ).
    IF lv_form IS INITIAL.
      lv_form = COND #( WHEN mv_arabic = abap_true THEN `ZPDF_FLIGHT_MANIFEST_AR` ELSE `ZPDF_FLIGHT_MANIFEST` ).
    ENDIF.
    IF lv_form IS NOT INITIAL.
      TRY.
          zcl_pdf_form_manager=>read_form( lv_form ).
        CATCH zcx_pdf.
          WRITE: / 'Note      : form', lv_form, 'not found; the built-in English template is used.',
                 / '            Start ZABAPPDF_STANDALONE once, or import the form XML.'.
          CLEAR lv_form.
      ENDTRY.
    ENDIF.

    TRY.
        IF lv_form IS NOT INITIAL.
          "Stored designer form: page size, margins, style and footer come from the form.
          lv_pdf = zcl_pdf_api=>render_pdf(
            iv_form_id = lv_form
            is_data    = ms_doc ).
          WRITE: / 'Template  : form', lv_form.
        ELSE.
          lv_pdf = zcl_pdf_api=>render_html(
            iv_html   = template( )
            iv_css    = css( )
            iv_footer = footer( )
            is_page   = ls_page
            is_data   = ms_doc ).
          WRITE: / 'Template  : built into the report'.
        ENDIF.
      CATCH zcx_pdf INTO DATA(lx_pdf).
        WRITE: / 'Render failed:', lx_pdf->get_text( ).
        RETURN.
    ENDTRY.

    WRITE: / 'Flight    :', ms_doc-carrier_id, ms_doc-connid, ms_doc-flight_date,
           / 'Route     :', ms_doc-cityfrom, '->', ms_doc-cityto,
           / 'Bookings  :', lines( ms_doc-bookings ),
           / 'Data      :', ms_doc-source,
           / 'PDF size  :', xstrlen( lv_pdf ), 'bytes'.

    IF p_down = abap_true.
      IF sy-batch = abap_true.
        WRITE: / 'Download  : skipped in background'.
      ELSE.
        TRY.
            zcl_pdf_api=>download_pdf(
              iv_pdf_xstring = lv_pdf
              iv_filename    = file_name( ) ).
            WRITE: / 'Download  : done'.
          CATCH zcx_pdf INTO lx_pdf.
            WRITE: / 'Download  :', lx_pdf->get_text( ).
        ENDTRY.
      ENDIF.
    ENDIF.

    IF p_mail = abap_true.
      TRY.
          send_mail( lv_pdf ).
          WRITE: / 'E-mail    : queued for', p_to, '(see SOST)'.
        CATCH cx_bcs INTO DATA(lx_bcs).
          WRITE: / 'E-mail    :', lx_bcs->get_text( ).
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD read_flight.
    DATA lr_conn TYPE RANGE OF s_conn_id.

    IF p_conn IS NOT INITIAL.
      lr_conn = VALUE #( ( sign = 'I' option = 'EQ' low = p_conn ) ).
    ENDIF.

    "Latest flight of the carrier that has bookings.
    SELECT carrid, connid, fldate, price, currency, planetype, seatsmax, seatsocc
      FROM sflight
      INTO TABLE @DATA(lt_flights)
      UP TO 1 ROWS
      WHERE carrid = @p_carr
        AND connid IN @lr_conn
        AND seatsocc > 0
      ORDER BY fldate DESCENDING.
    READ TABLE lt_flights INTO DATA(ls_flight) INDEX 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT SINGLE carrname FROM scarr
      INTO @DATA(lv_carrname)
      WHERE carrid = @ls_flight-carrid.

    SELECT SINGLE cityfrom, cityto, airpfrom, airpto, deptime, arrtime
      FROM spfli
      INTO @DATA(ls_route)
      WHERE carrid = @ls_flight-carrid
        AND connid = @ls_flight-connid.

    "Amounts in the airline's currency (LOCCURAM), so the total adds up in one currency.
    SELECT bookid, customid, passname, class, loccuram, loccurkey, order_date
      FROM sbook
      INTO TABLE @DATA(lt_book)
      UP TO @p_max ROWS
      WHERE carrid = @ls_flight-carrid
        AND connid = @ls_flight-connid
        AND fldate = @ls_flight-fldate
        AND cancelled = @space
      ORDER BY bookid.

    ms_doc-carrier_id = ls_flight-carrid.
    ms_doc-carrier_name = lv_carrname.
    ms_doc-connid = |{ ls_flight-connid ALPHA = OUT }|.
    ms_doc-cityfrom = ls_route-cityfrom.
    ms_doc-cityto = ls_route-cityto.
    ms_doc-airpfrom = ls_route-airpfrom.
    ms_doc-airpto = ls_route-airpto.
    ms_doc-flight_date = |{ ls_flight-fldate DATE = USER }|.
    ms_doc-deptime = |{ ls_route-deptime(2) }:{ ls_route-deptime+2(2) }|.
    ms_doc-arrtime = |{ ls_route-arrtime(2) }:{ ls_route-arrtime+2(2) }|.
    ms_doc-planetype = ls_flight-planetype.
    ms_doc-seats = |{ ls_flight-seatsocc } / { ls_flight-seatsmax }|.
    ms_doc-price = |{ ls_flight-price DECIMALS = 2 }|.
    ms_doc-currency = currency_text( ls_flight-currency ).
    ms_doc-source = 'SFLIGHT / SBOOK'.

    LOOP AT lt_book INTO DATA(ls_book).
      APPEND VALUE #(
        bookid     = |{ ls_book-bookid ALPHA = OUT }|
        customid   = |{ ls_book-customid ALPHA = OUT }|
        passname   = ls_book-passname
        class      = class_text( ls_book-class )
        amount     = |{ ls_book-loccuram DECIMALS = 2 }|
        currency   = currency_text( ls_book-loccurkey )
        order_date = |{ ls_book-order_date DATE = USER }| ) TO ms_doc-bookings.
    ENDLOOP.

    rv_found = abap_true.
  ENDMETHOD.

  METHOD sample_flight.
    DATA lv_amount TYPE p LENGTH 13 DECIMALS 2.
    DATA lv_index TYPE i.
    DATA lt_names TYPE string_table.
    DATA lv_name TYPE string.
    DATA lv_date TYPE d.

    IF mv_arabic = abap_true.
      ms_doc = VALUE #(
        carrier_id   = 'SV'
        carrier_name = 'الخطوط السعودية'
        connid       = '1020'
        cityfrom     = 'الرياض'
        cityto       = 'جدة'
        airpfrom     = 'RUH'
        airpto       = 'JED'
        flight_date  = |{ sy-datum DATE = USER }|
        deptime      = '08:30'
        arrtime      = '10:15'
        planetype    = 'A320'
        seats        = '18 / 186'
        price        = '450.00'
        currency     = currency_text( 'SAR' )
        source       = 'بيانات تجريبية (جداول الرحلات فارغة)' ).
      lt_names = VALUE #( ( `ناصر علي` ) ( `سارة أحمد` ) ( `فهد محمد` ) ( `نورة صالح` )
                          ( `خالد عبدالله` ) ( `ريم سعد` ) ( `عبدالرحمن فيصل` ) ( `هند ماجد` ) ).
    ELSE.
      ms_doc = VALUE #(
        carrier_id   = p_carr
        carrier_name = 'Lufthansa'
        connid       = '400'
        cityfrom     = 'FRANKFURT'
        cityto       = 'NEW YORK'
        airpfrom     = 'FRA'
        airpto       = 'JFK'
        flight_date  = |{ sy-datum DATE = USER }|
        deptime      = '10:10'
        arrtime      = '11:34'
        planetype    = 'A340-600'
        seats        = '18 / 330'
        price        = '666.00'
        currency     = 'EUR'
        source       = 'Sample data (flight tables are empty)' ).
      lt_names = VALUE #( ( `Anna Schmidt` ) ( `Nasser Ali` ) ( `John Miller` ) ( `Sara Ahmed` )
                          ( `Lukas Weber` ) ( `Fahd Mohammed` ) ( `Emma Johnson` ) ( `Noura Saleh` ) ).
    ENDIF.
    DO nmin( val1 = p_max val2 = 18 ) TIMES.
      lv_index = sy-index.
      READ TABLE lt_names INTO lv_name INDEX ( lv_index - 1 ) MOD lines( lt_names ) + 1.
      lv_amount = 450 + ( lv_index * 137 ) MOD 900.
      lv_date = sy-datum - lv_index.
      APPEND VALUE #(
        bookid     = |{ 1000 + lv_index }|
        customid   = |{ 4000 + lv_index * 7 }|
        passname   = lv_name
        class      = class_text( SWITCH s_class( lv_index MOD 6 WHEN 0 THEN 'F' WHEN 1 OR 2 THEN 'C' ELSE 'Y' ) )
        amount     = |{ lv_amount DECIMALS = 2 }|
        currency   = ms_doc-currency
        order_date = |{ lv_date DATE = USER }| ) TO ms_doc-bookings.
    ENDDO.
  ENDMETHOD.

  METHOD class_text.
    CASE iv_class.
      WHEN 'F'.
        rv_text = COND #( WHEN mv_arabic = abap_true THEN `أولى` ELSE `First` ).
      WHEN 'C'.
        rv_text = COND #( WHEN mv_arabic = abap_true THEN `أعمال` ELSE `Business` ).
      WHEN OTHERS.
        rv_text = COND #( WHEN mv_arabic = abap_true THEN `سياحية` ELSE `Economy` ).
    ENDCASE.
  ENDMETHOD.

  METHOD currency_text.
    "The Arabic form shows common currencies by name; other codes stay as they are.
    rv_text = iv_currency.
    IF mv_arabic = abap_false.
      RETURN.
    ENDIF.
    CASE iv_currency.
      WHEN 'SAR'.
        rv_text = `ريال`.
      WHEN 'EUR'.
        rv_text = `يورو`.
      WHEN 'USD'.
        rv_text = `دولار`.
      WHEN 'GBP'.
        rv_text = `جنيه إسترليني`.
      WHEN 'JPY'.
        rv_text = `ين`.
    ENDCASE.
  ENDMETHOD.

  METHOD template.
    "Tags: {{FIELD}} for values, {{#each BOOKINGS}} for rows, {{count}}/{{sum}} for totals.
    rv_html =
      `<h1 style="color:#1d4e89;margin-bottom:2mm">Passenger Manifest</h1>` &&
      `<p style="color:gray;margin-top:0">{{CARRIER_NAME}} ({{CARRIER_ID}}) &middot; printed {{PRINTED_AT}}</p>` &&
      `<table style="width:100%;margin-bottom:6mm">` &&
      `<tr><td style="width:25%;color:gray">Flight</td><td style="width:25%"><b>{{CARRIER_ID}} {{CONNID}}</b></td>` &&
      `<td style="width:25%;color:gray">Date</td><td style="width:25%"><b>{{FLIGHT_DATE}}</b></td></tr>` &&
      `<tr><td style="color:gray">From</td><td>{{CITYFROM}} ({{AIRPFROM}}) {{DEPTIME}}</td>` &&
      `<td style="color:gray">To</td><td>{{CITYTO}} ({{AIRPTO}}) {{ARRTIME}}</td></tr>` &&
      `<tr><td style="color:gray">Aircraft</td><td>{{PLANETYPE}}</td>` &&
      `<td style="color:gray">Seats occupied</td><td>{{SEATS}}</td></tr>` &&
      `<tr><td style="color:gray">Ticket price</td><td><span data-fmt="#,##0.00">{{PRICE}}</span> {{CURRENCY}}</td>` &&
      `<td style="color:gray">Data source</td><td>{{SOURCE}}</td></tr>` &&
      `</table>` &&
      `<table style="width:100%">` &&
      `<thead><tr><th style="width:6%">#</th><th style="width:12%">Booking</th><th style="width:12%">Customer</th>` &&
      `<th style="width:30%">Passenger</th><th style="width:12%">Class</th><th style="width:14%">Booked on</th>` &&
      `<th style="width:14%;text-align:right">Amount</th></tr></thead>` &&
      `<tbody>{{#each BOOKINGS}}<tr><td>{{ROW}}</td><td>{{BOOKID}}</td><td>{{CUSTOMID}}</td><td>{{PASSNAME}}</td>` &&
      `<td>{{CLASS}}</td><td>{{ORDER_DATE}}</td>` &&
      `<td style="text-align:right"><span data-fmt="#,##0.00">{{AMOUNT}}</span> {{CURRENCY}}</td></tr>` &&
      `{{else}}<tr><td colspan="7">No bookings</td></tr>{{/each}}</tbody>` &&
      `<tfoot><tr><td colspan="5"><b>{{count BOOKINGS}} passengers</b></td><td style="text-align:right"><b>Total</b></td>` &&
      `<td style="text-align:right"><b><span data-fmt="#,##0.00">{{sum BOOKINGS.AMOUNT}}</span></b></td></tr></tfoot>` &&
      `</table>`.
  ENDMETHOD.

  METHOD css.
    "The native engine applies rules by tag name.
    rv_css =
      `body { font-family: Helvetica; font-size: 9pt; color: #1f2937; }` &&
      `th { background-color: #1d4e89; color: white; padding: 2mm; text-align: left; font-size: 8pt; }` &&
      `td { padding: 1.5mm; border-bottom: 0.2mm solid #d1d5db; }`.
  ENDMETHOD.

  METHOD footer.
    rv_html = `<div style="text-align:center;font-size:7pt;color:gray">` &&
              `{{CARRIER_ID}} {{CONNID}} &middot; {{FLIGHT_DATE}} &middot; ` &&
              `Page <span class="pageNumber"></span> of <span class="totalPages"></span></div>`.
  ENDMETHOD.

  METHOD file_name.
    rv_name = |Manifest_{ ms_doc-carrier_id }{ ms_doc-connid }_{ sy-datum }.pdf|.
  ENDMETHOD.

  METHOD send_mail.
    DATA lt_text TYPE bcsy_text.

    lt_text = VALUE #(
      ( line = 'Hello,' )
      ( line = '' )
      ( line = |Please find attached the passenger manifest for flight { ms_doc-carrier_id } { ms_doc-connid }| )
      ( line = |on { ms_doc-flight_date } ({ ms_doc-cityfrom } - { ms_doc-cityto }), { lines( ms_doc-bookings ) } passengers.| )
      ( line = '' )
      ( line = 'Generated by the abapPDF demo report ZABAPPDF_DEMO_FLIGHTS.' ) ).

    DATA(lo_doc) = cl_document_bcs=>create_document(
      i_type    = 'RAW'
      i_text    = lt_text
      i_subject = CONV so_obj_des( |Passenger manifest { ms_doc-carrier_id } { ms_doc-connid } { ms_doc-flight_date }| ) ).

    lo_doc->add_attachment(
      i_attachment_type    = 'PDF'
      i_attachment_subject = CONV so_obj_des( file_name( ) )
      i_attachment_size    = CONV so_obj_len( xstrlen( iv_pdf ) )
      i_att_content_hex    = cl_bcs_convert=>xstring_to_solix( iv_pdf ) ).

    DATA(lo_send) = cl_bcs=>create_persistent( ).
    lo_send->set_document( lo_doc ).
    lo_send->add_recipient( cl_cam_address_bcs=>create_internet_address( p_to ) ).
    lo_send->set_send_immediately( abap_true ).
    lo_send->send( ).
    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.

AT SELECTION-SCREEN.
  IF p_mail = abap_true AND p_to IS INITIAL.
    MESSAGE 'Enter the e-mail address (P_TO) to send the manifest' TYPE 'E'.
  ENDIF.
  IF p_max <= 0.
    MESSAGE 'P_MAX must be greater than 0' TYPE 'E'.
  ENDIF.

START-OF-SELECTION.
  NEW lcl_demo( )->run( ).
