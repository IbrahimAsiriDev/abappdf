class ZCL_PDF_CONVERT definition
  public
  final
  create private .

public section.

  class-methods STRING_TO_XSTRING
    importing
      !IV_STRING type STRING
    returning
      value(RV_XSTRING) type XSTRING
    raising
      ZCX_PDF .
  class-methods XSTRING_TO_STRING
    importing
      !IV_XSTRING type XSTRING
    returning
      value(RV_STRING) type STRING
    raising
      ZCX_PDF .
  class-methods BASE64URL_DECODE
    importing
      !IV_B64 type STRING
    returning
      value(RV_STRING) type STRING
    raising
      ZCX_PDF .
  class-methods BASE64_DECODE
    importing
      !IV_B64 type STRING
    returning
      value(RV_STRING) type STRING
    raising
      ZCX_PDF .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_PDF_CONVERT IMPLEMENTATION.


  METHOD string_to_xstring.
    IF iv_string IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_out) = cl_abap_conv_out_ce=>create( encoding = 'UTF-8' ).
        lo_out->convert(
          EXPORTING
            data   = iv_string
          IMPORTING
            buffer = rv_xstring ).
      CATCH cx_root INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_pdf
          EXPORTING
            previous = lx_error
            message  = |UTF-8 encode failed: { lx_error->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.


  METHOD xstring_to_string.
    IF iv_xstring IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_in) = cl_abap_conv_in_ce=>create(
          input    = iv_xstring
          encoding = 'UTF-8' ).
        lo_in->read( IMPORTING data = rv_string ).
      CATCH cx_root INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_pdf
          EXPORTING
            previous = lx_error
            message  = |UTF-8 decode failed: { lx_error->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.


  METHOD base64_decode.
    DATA lv_b64 TYPE string.
    lv_b64 = iv_b64.
    CONDENSE lv_b64 NO-GAPS.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN lv_b64 WITH ''.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf+0(1) IN lv_b64 WITH ''.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_b64 WITH ''.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN lv_b64 WITH ''.
    IF lv_b64 IS INITIAL.
      RETURN.
    ENDIF.
    rv_string = xstring_to_string( cl_http_utility=>decode_x_base64( lv_b64 ) ).
  ENDMETHOD.


  METHOD base64url_decode.
    DATA lv_b64 TYPE string.
    DATA lv_len TYPE i.
    DATA lv_mod TYPE i.

    lv_b64 = iv_b64.
    CONDENSE lv_b64 NO-GAPS.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN lv_b64 WITH ''.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf+0(1) IN lv_b64 WITH ''.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_b64 WITH ''.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN lv_b64 WITH ''.
    REPLACE ALL OCCURRENCES OF '-' IN lv_b64 WITH '+'.
    REPLACE ALL OCCURRENCES OF '_' IN lv_b64 WITH '/'.

    IF lv_b64 IS INITIAL.
      RETURN.
    ENDIF.

    lv_len = strlen( lv_b64 ).
    lv_mod = lv_len MOD 4.
    IF lv_mod = 2.
      lv_b64 = lv_b64 && '=='.
    ELSEIF lv_mod = 3.
      lv_b64 = lv_b64 && '='.
    ELSEIF lv_mod = 1.
      RAISE EXCEPTION TYPE zcx_pdf
        EXPORTING
          message = 'Designer payload is not valid base64url'.
    ENDIF.

    rv_string = xstring_to_string( cl_http_utility=>decode_x_base64( lv_b64 ) ).
  ENDMETHOD.
ENDCLASS.
