## Summary
An appdesigner table component where the table is created from builtin or custom appdesigner components. NB: As this table is built using individual appdesigner components for each cell, it is not very scalable and mostly suitable for smaller tables (i.e <100 rows).

## Examples
See the [examples](https://github.com/ehennestad/WidgetTable/tree/main/widget_table/examples) folder for examples

## Preview
![widget_table_demo](https://github.com/ehennestad/WidgetTable/assets/17237719/0c84fb16-5ef8-47c3-b0fe-7b48c4c4d972)

## Notes
This is a work in progress, so please report bugs, ideas etc under issues
- Known limitations:
- Resizing (e.g when resizing figure) does not always update properly. 
- Built to supports struct data, but not tested for that, so probably does not work
- Selection is not supported yet
- Takes time to build large tables. One idea for implementation is to make table pages
