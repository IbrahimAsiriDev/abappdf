CLASS ltc_arabic DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS shaping FOR TESTING.
ENDCLASS.

CLASS ltc_arabic IMPLEMENTATION.

  METHOD shaping.
    "سلام: seen initial, lam-alef final ligature, meem isolated (alef does not join the next letter).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pdf_arabic=>shape( VALUE #( ( 1587 ) ( 1604 ) ( 1575 ) ( 1605 ) ) )
      exp = VALUE zcl_pdf_arabic=>ty_ints( ( 65203 ) ( 65276 ) ( 65249 ) ) ).
    "باب: beh initial, alef final, beh isolated.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_pdf_arabic=>shape( VALUE #( ( 1576 ) ( 1575 ) ( 1576 ) ) )
      exp = VALUE zcl_pdf_arabic=>ty_ints( ( 65169 ) ( 65166 ) ( 65167 ) ) ).
  ENDMETHOD.

ENDCLASS.
