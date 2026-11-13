CLASS ltc_renderer DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS invalid_page_area FOR TESTING.
    METHODS native_latin FOR TESTING RAISING zcx_pdf.
    METHODS native_arabic FOR TESTING RAISING zcx_pdf.
    METHODS assert_pdf
      IMPORTING iv_pdf TYPE xstring.
    METHODS a4
      RETURNING VALUE(rs_page) TYPE zcl_pdf_renderer=>ty_page.
ENDCLASS.

CLASS ltc_renderer IMPLEMENTATION.

  METHOD invalid_page_area.
    DATA ls_page TYPE zcl_pdf_renderer=>ty_page.
    ls_page-page_size = 'A4'.
    ls_page-orientation = 'P'.
    ls_page-margin_left = 110.
    ls_page-margin_right = 110.
    TRY.
        zcl_pdf_renderer=>validate_page( ls_page ).
        cl_abap_unit_assert=>fail( 'Margins consuming the page must fail' ).
      CATCH zcx_pdf INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( lx_error->get_text( ) CS 'printable page area' ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD native_latin.
    "The native engine writes a complete PDF without Gotenberg.
    assert_pdf( zcl_pdf_native=>render(
      iv_html = `<h1>Invoice</h1><table><tr><td>MAT-100</td><td>50.00</td></tr></table>`
      is_page = a4( ) ) ).
  ENDMETHOD.

  METHOD native_arabic.
    assert_pdf( zcl_pdf_native=>render(
      iv_html = `<div dir="rtl"><h1>كشف حساب</h1><p>شركة النور للتجارة - 100245</p></div>`
      is_page = a4( ) ) ).
  ENDMETHOD.

  METHOD assert_pdf.
    CONSTANTS lc_magic TYPE x LENGTH 4 VALUE '25504446'. "%PDF
    DATA lv_head TYPE x LENGTH 4.
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( xstrlen( iv_pdf ) > 200 )
      msg = 'PDF is empty or too small' ).
    lv_head = iv_pdf(4).
    cl_abap_unit_assert=>assert_equals(
      act = lv_head
      exp = lc_magic
      msg = 'Output does not start with %PDF' ).
  ENDMETHOD.

  METHOD a4.
    rs_page-page_size = 'A4'.
    rs_page-orientation = 'P'.
    rs_page-margin_top = 12.
    rs_page-margin_right = 10.
    rs_page-margin_bottom = 16.
    rs_page-margin_left = 10.
  ENDMETHOD.

ENDCLASS.
