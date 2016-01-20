# Replace lines starting with fn>> to 
(s/^BT>(.+)\n/\1/ && print `objdump -dl $_ asmcc|tail -n+7`)
    || print for(<>);
