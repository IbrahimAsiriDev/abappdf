CLASS zcl_pdf_api DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS render_pdf
      IMPORTING
        iv_form_id          TYPE csequence
        is_data             TYPE any
      RETURNING
        VALUE(rv_pdf_xstring) TYPE xstring
      RAISING
        zcx_pdf.

    CLASS-METHODS render_html
      IMPORTING
        iv_html             TYPE string
        iv_css              TYPE string OPTIONAL
        iv_header           TYPE string OPTIONAL
        iv_footer           TYPE string OPTIONAL
        is_page             TYPE zcl_pdf_renderer=>ty_page OPTIONAL
        is_data             TYPE any
      RETURNING
        VALUE(rv_pdf_xstring) TYPE xstring
      RAISING
        zcx_pdf.

    CLASS-METHODS download_pdf
      IMPORTING
        iv_pdf_xstring TYPE xstring
        iv_filename    TYPE string DEFAULT 'document.pdf'
        iv_open        TYPE abap_bool DEFAULT abap_true
        iv_dialog      TYPE abap_bool DEFAULT abap_true
      EXPORTING
        ev_fullpath    TYPE string
      RAISING
        zcx_pdf.

    CLASS-METHODS expand_layout
      IMPORTING
        is_template        TYPE zcl_pdf_form_manager=>ty_template
      RETURNING
        VALUE(rs_template) TYPE zcl_pdf_form_manager=>ty_template.

  PRIVATE SECTION.
    CLASS-METHODS is_form_xml
      IMPORTING
        iv_xml         TYPE string
      RETURNING
        VALUE(rv_yes)  TYPE abap_bool.

    CLASS-METHODS xml_tag
      IMPORTING
        iv_xml         TYPE string
        iv_tag         TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS xml_attr
      IMPORTING
        iv_page        TYPE string
        iv_name        TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.

    CLASS-METHODS xml_int
      IMPORTING
        iv_text      TYPE string
      RETURNING
        VALUE(rv_int) TYPE i.
ENDCLASS.



CLASS zcl_pdf_api IMPLEMENTATION.

  METHOD render_pdf.
    DATA lv_form_id TYPE string.
    DATA ls_template TYPE zcl_pdf_form_manager=>ty_template.
    DATA ls_page TYPE zcl_pdf_renderer=>ty_page.

    lv_form_id = iv_form_id.
    CONDENSE lv_form_id.
    IF lv_form_id IS INITIAL.
      RAISE EXCEPTION TYPE zcx_pdf
        EXPORTING
          message = 'Form ID is empty'.
    ENDIF.

    "Page size, orientation and margins are taken from the saved form.
    ls_template = zcl_pdf_form_manager=>read_active_template( to_upper( lv_form_id ) ).
    ls_page-page_size = ls_template-page_size.
    ls_page-orientation = ls_template-orientation.
    ls_page-margin_top = ls_template-margin_top.
    ls_page-margin_right = ls_template-margin_right.
    ls_page-margin_bottom = ls_template-margin_bottom.
    ls_page-margin_left = ls_template-margin_left.

    rv_pdf_xstring = render_html(
      iv_html   = ls_template-html_content
      iv_css    = ls_template-css_content
      iv_header = ls_template-header_html
      iv_footer = ls_template-footer_html
      is_page   = ls_page
      is_data   = is_data ).
  ENDMETHOD.


  METHOD render_html.
    "Bind the data into each part, then render (native engine unless ENGINE = GOTENBERG).
    DATA lo_renderer TYPE REF TO zcl_pdf_renderer.

    CREATE OBJECT lo_renderer.
    rv_pdf_xstring = lo_renderer->render(
      iv_html   = zcl_pdf_data_binder=>render( iv_template = iv_html   is_data = is_data )
      iv_css    = zcl_pdf_data_binder=>render( iv_template = iv_css    is_data = is_data )
      iv_header = zcl_pdf_data_binder=>render( iv_template = iv_header is_data = is_data )
      iv_footer = zcl_pdf_data_binder=>render( iv_template = iv_footer is_data = is_data )
      is_page   = is_page ).
  ENDMETHOD.


  METHOD download_pdf.
    DATA lv_file TYPE string.
    DATA lv_path TYPE string.
    DATA lv_full TYPE string.
    DATA lv_action TYPE i.
    DATA lv_len TYPE i.
    DATA lv_off TYPE i.
    DATA lv_chunk TYPE i.
    TYPES ty_raw TYPE x LENGTH 255.
    DATA lt_bin TYPE STANDARD TABLE OF ty_raw WITH EMPTY KEY.

    IF iv_pdf_xstring IS INITIAL.
      RAISE EXCEPTION TYPE zcx_pdf
        EXPORTING
          message = 'PDF payload is empty'.
    ENDIF.

    IF iv_dialog = abap_false.
      cl_gui_frontend_services=>get_desktop_directory(
        CHANGING
          desktop_directory = lv_path
        EXCEPTIONS
          OTHERS            = 1 ).
      IF lv_path IS INITIAL.
        cl_gui_frontend_services=>get_temp_directory(
          CHANGING
            temp_dir = lv_path
          EXCEPTIONS
            OTHERS   = 1 ).
      ENDIF.
      IF lv_path IS INITIAL.
        lv_path = 'C:\Temp\'.
      ENDIF.
      lv_len = strlen( lv_path ) - 1.
      IF lv_path+lv_len(1) <> '\' AND lv_path+lv_len(1) <> '/'.
        lv_path = lv_path && '\'.
      ENDIF.
      lv_full = lv_path && iv_filename.
    ELSE.
      cl_gui_frontend_services=>file_save_dialog(
        EXPORTING
          window_title         = 'Save PDF'
          default_extension    = 'pdf'
          default_file_name    = iv_filename
          file_filter          = 'PDF (*.pdf)|*.pdf'
        CHANGING
          filename             = lv_file
          path                 = lv_path
          fullpath             = lv_full
          user_action          = lv_action
        EXCEPTIONS
          cntl_error           = 1
          error_no_gui         = 2
          not_supported_by_gui = 3
          OTHERS               = 4 ).
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_pdf
          EXPORTING
            message = 'Save dialog failed'.
      ENDIF.
      IF lv_action <> cl_gui_frontend_services=>action_ok OR lv_full IS INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    lv_len = xstrlen( iv_pdf_xstring ).
    WHILE lv_off < lv_len.
      lv_chunk = lv_len - lv_off.
      IF lv_chunk > 255.
        lv_chunk = 255.
      ENDIF.
      APPEND iv_pdf_xstring+lv_off(lv_chunk) TO lt_bin.
      lv_off = lv_off + lv_chunk.
    ENDWHILE.

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        bin_filesize     = lv_len
        filename         = lv_full
        filetype         = 'BIN'
      CHANGING
        data_tab         = lt_bin
      EXCEPTIONS
        file_write_error = 1
        no_batch         = 2
        gui_refuse_filetransfer = 3
        invalid_type     = 4
        no_authority     = 5
        unknown_error    = 6
        OTHERS           = 7 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_pdf
        EXPORTING
          message = |Could not write { lv_full }|.
    ENDIF.

    IF iv_open = abap_true.
      cl_gui_frontend_services=>execute(
        EXPORTING
          document = lv_full
        EXCEPTIONS
          OTHERS   = 1 ).
    ENDIF.
    ev_fullpath = lv_full.
  ENDMETHOD.


  METHOD expand_layout.
    DATA lv_xml TYPE string.
    DATA lv_page TYPE string.
    DATA lv_start TYPE i.
    DATA lv_end TYPE i.
    DATA lv_rest TYPE string.

    rs_template = is_template.
    lv_xml = is_template-html_content.
    IF is_form_xml( lv_xml ) = abap_false.
      RETURN.
    ENDIF.

    rs_template-html_content = xml_tag( iv_xml = lv_xml iv_tag = 'body' ).
    rs_template-css_content = xml_tag( iv_xml = lv_xml iv_tag = 'style' ).
    rs_template-header_html = xml_tag( iv_xml = lv_xml iv_tag = 'header' ).
    rs_template-footer_html = xml_tag( iv_xml = lv_xml iv_tag = 'footer' ).
    rs_template-sample_json = xml_tag( iv_xml = lv_xml iv_tag = 'sample' ).

    FIND '<page' IN lv_xml MATCH OFFSET lv_start.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    lv_rest = substring( val = lv_xml off = lv_start ).
    FIND '>' IN lv_rest MATCH OFFSET lv_end.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    lv_page = substring( val = lv_rest len = lv_end ).
    rs_template-page_size = xml_attr( iv_page = lv_page iv_name = 'size' ).
    rs_template-orientation = xml_attr( iv_page = lv_page iv_name = 'orientation' ).
    rs_template-margin_top = xml_int( xml_attr( iv_page = lv_page iv_name = 'top' ) ).
    rs_template-margin_right = xml_int( xml_attr( iv_page = lv_page iv_name = 'right' ) ).
    rs_template-margin_bottom = xml_int( xml_attr( iv_page = lv_page iv_name = 'bottom' ) ).
    rs_template-margin_left = xml_int( xml_attr( iv_page = lv_page iv_name = 'left' ) ).
  ENDMETHOD.


  METHOD is_form_xml.
    DATA lv_text TYPE string.
    lv_text = iv_xml.
    SHIFT lv_text LEFT DELETING LEADING space.
    IF strlen( lv_text ) >= 5 AND substring( val = lv_text len = 5 ) = '<?xml'.
      rv_yes = abap_true.
      RETURN.
    ENDIF.
    IF strlen( lv_text ) >= 8 AND substring( val = lv_text len = 8 ) = '<abappdf'.
      rv_yes = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD xml_tag.
    DATA lv_open TYPE string.
    DATA lv_close TYPE string.
    DATA lv_rest TYPE string.
    DATA lv_start TYPE i.
    DATA lv_end TYPE i.

    lv_open = '<' && iv_tag && '>'.
    lv_close = '</' && iv_tag && '>'.
    FIND lv_open IN iv_xml MATCH OFFSET lv_start.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    lv_start = lv_start + strlen( lv_open ).
    lv_rest = substring( val = iv_xml off = lv_start ).
    FIND lv_close IN lv_rest MATCH OFFSET lv_end.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rv_text = substring( val = lv_rest len = lv_end ).
    IF strlen( rv_text ) >= 9 AND substring( val = rv_text len = 9 ) = '<![CDATA['.
      rv_text = substring( val = rv_text off = 9 ).
    ENDIF.
    lv_end = strlen( rv_text ).
    IF lv_end >= 3.
      lv_start = lv_end - 3.
      IF substring( val = rv_text off = lv_start len = 3 ) = ']]>'.
        rv_text = substring( val = rv_text len = lv_start ).
      ENDIF.
    ENDIF.
    REPLACE ALL OCCURRENCES OF ']]]]><![CDATA[>' IN rv_text WITH ']]>'.
  ENDMETHOD.


  METHOD xml_attr.
    DATA lv_key TYPE string.
    DATA lv_rest TYPE string.
    DATA lv_start TYPE i.
    DATA lv_end TYPE i.

    lv_key = iv_name && '="'.
    FIND lv_key IN iv_page MATCH OFFSET lv_start.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    lv_start = lv_start + strlen( lv_key ).
    lv_rest = substring( val = iv_page off = lv_start ).
    FIND '"' IN lv_rest MATCH OFFSET lv_end.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rv_value = substring( val = lv_rest len = lv_end ).
    CONDENSE rv_value.
  ENDMETHOD.


  METHOD xml_int.
    DATA lv_text TYPE string.
    lv_text = iv_text.
    CONDENSE lv_text NO-GAPS.
    IF lv_text IS NOT INITIAL AND lv_text CO '0123456789'.
      rv_int = lv_text.
    ENDIF.
  ENDMETHOD.

ENDCLASS.