;   ********************************************************************************************
;   *** ELIZA is an early rogerian psychotherapist chatterbot originally written             ***
;   *** by Joseph Weizenbaum between 1964 to 1967 , below implementation is based on         ***
;   *** simplified Basic version of Eliza Doctor by Jeff Shrager 1973                        ***
;   *** Adapted to Minimal 64x4 assembly by Mateusz Matysiak (Hellboy73) May 2025            ***
;   *** Change log:                                                                          ***
;   *** v1.0 26.05.2025 initial fully working version                                        ***
;   *** v1.1 02.06.2025 minor tweaks and bugfixes,                                           ***
;   ***                 more keywords and responses added for variety,                       ***
;   ***                 answers are now pseudo-randomized to minimize predictability         ***
;   ********************************************************************************************
#org 0x8000
;   *************************************
;   *** Initial Section               ***
;   *************************************
init:
    LDI 0xfe STB 0xffff                         ; reset stack
    MIW 0x45a1 _RandomState                     ; first initiation of pseudo-random generator
    MIW 0xf32d _RandomState+2
    JPS _ClearVRAM                              ; clear screen
    JPS draw_eliza_logo                         ; display logo and title screen
    MIZ 0 _YPos MIZ 7 _XPos JPS _Print " ------- ELIZA v1.1 for Minimal64x4 -------" 0
    MIZ 1 _YPos MIZ 7 _XPos JPS _Print " Adapted by Mateusz Matysiak 2025  based on" 0
    MIZ 2 _YPos MIZ 7 _XPos JPS _Print " Basic implementation  by Jeff Shrager 1973" 0
    MIZ 3 _YPos MIZ 7 _XPos JPS _Print " Original concept by Joseph Weizenbaum 1966" 0
    MIZ 4 _YPos MIZ 7 _XPos JPS _Print " ------------------------------------------" 0
    MIZ 7 _YPos MIZ 0 _XPos     MIW greeting_line_1 pb_ptr  JPS print_buffer
    MIZ 8 _YPos MIZ 0 _XPos     MIW greeting_line_2 pb_ptr  JPS print_buffer
    MIZ 9 _YPos MIZ 0 _XPos
    JPA start
    greeting_line_1: "HI I'M ELIZA, YOUR PSYCHOTHERAPIST. "  0
    greeting_line_2: "PLEASE TELL ME WHAT BRINGS YOU HERE TODAY." 0

;   *************************************
;   *** Main Loop section             ***
;   *************************************
start:
    JPS clear_buffers
    MIZ 0 _XPos LDI "~" JAS _PrintChar
    MIV _ReadBuffer,_ReadPtr                    ; initiate _ReadPtr as in OS procedures
    JPS _ReadLine                               ; getting user input into _ReadBuffer
    LDB _ReadBuffer CPI 0x0a    BEQ start       ; is it empty string? then read again
    MWV _ReadBuffer+2 _RandomState  
    JAS _Random     STB random_counter          ; alter random generator seed with user prompt for less predictibility
    JPS first_parsing                           ; initial parsing of user input, deleting special chars, adding spaces etc.
    JPS uppercase                               ; coverting input to uppercase to unify further text parsing
    ; *** looking for BYE
        MIW first_buffer    kws_buf_ptr         ; init pointers for keword search
        MIW keyword_bye     kws_kwd_ptr         ; searching for BYE
        JPS keyword_search
        CPI 0 BEQ bye_not_found
        MIW response_bye pb_ptr JPS print_buffer
        JPA _Prompt                             ; exiting Eliza, back to OS prompt
    bye_not_found:
    ; *** looking for SHUT
        MIW first_buffer    kws_buf_ptr         ; init pointers for keword search
        MIW keyword_shut    kws_kwd_ptr         ; searching for SHUT
        JPS keyword_search
        CPI 0 BEQ shut_not_found
        MIW response_shut pb_ptr    JPS print_buffer
        JPA _Prompt                             ; exiting Eliza, back to OS prompt
    shut_not_found:
    ; *** checking if input is the same as last input and responding accordingly
        MIW first_buffer cs_ptr1
        MIW last_input   cs_ptr2
        JPS compare_strings
        CPI 0 BEQ repeat_not_found
        MIW response_repeat pb_ptr  JPS print_buffer    JPA start
    repeat_not_found:
    ; *** copying current input to last input
        MIW first_buffer copy_src_ptr
        MIW last_input   copy_dst_ptr
        JPS copy_strings

    ; *** parsing input for keywords - keyword searching loop
    CLZ Z6                                          ; clearing zero page index
    keyword_search_loop:
            MIB 0 found_keyword_length
            LZB Z6 keywords     STB keyword_ptr
            LZB Z6 keywords+1   STB keyword_ptr+1   ; getting keyword pointer from z-indexed list
            MIW first_buffer    kws_buf_ptr         ; init pointers for keyword search
            MBB keyword_ptr     kws_kwd_ptr
            MBB keyword_ptr+1   kws_kwd_ptr+1
            JPS keyword_search                      ; searching for keyword
                CPI 0 BNE keyword_found             ; if A<>0 keyword found
                INZ Z6 INZ Z6                       ; increase keyword pointer
                LZB Z6 keywords
                CPI 0 BNE keyword_search_loop       ; check if end of keyword list
                INZ Z6                              ; just to be sure check second byte of this pointer (list ends with 0x0000)
                LZB Z6 keywords CPI 0 BEQ no_keyword_found
                DEZ Z6
            JPA keyword_search_loop                 ; loop again to search for next word on the list
        keyword_found:
                STB found_keyword_length
                JPA keyword_search_loop_end
        no_keyword_found:
                MIB 0 found_keyword_length
                MIW kw_nf keyword_ptr
    keyword_search_loop_end:                        ; found keyword pointer is now in keyword_ptr, length in found_keyword_length

    ; *** checking for an reply related to keyword
        MBB keyword_ptr     keyword_temp_ptr        ; clone the pointer for calculations
        MBB keyword_ptr+1   keyword_temp_ptr+1
        ABW found_keyword_length keyword_temp_ptr   ; skip keyword itself
        INW keyword_temp_ptr                        ; skip zero byte EOS
        LDR keyword_temp_ptr  STB repl_ptr   STB last_repl_ptr     ; read and store reply pointer
        INW keyword_temp_ptr
        LDR keyword_temp_ptr  STB repl_ptr+1 STB last_repl_ptr+1   ; found reply is now pointed by reply_ptr
        
        ; *** randomizing answers 
        randomizing_loop:                           ; this loop runs random number of times to pick random answer from list
            LDR repl_ptr    STB repl_ptr2   INW repl_ptr
            LDR repl_ptr    STB repl_ptr2+1
            MBB repl_ptr2   repl_ptr    
            MBB repl_ptr2+1 repl_ptr+1  
            LDB random_counter CPI 0 BEQ randomizing_loop_check_last
            DEB random_counter JPA randomizing_loop ; if counter not zero, go loop again
        randomizing_loop_check_last:
            CBB repl_ptr    last_repl_ptr           ; check if response is the same as last one and if yes, run again
            BNE randomizing_loop_end
            CBB repl_ptr+1  last_repl_ptr+1     
            BNE randomizing_loop_end 
            JPA randomizing_loop                    ; if response is the same, try randomizing one more time
        randomizing_loop_end:       
            MIW output_buffer   copy_dst_ptr        ; prep to copy reply into output buffer
            MBB repl_ptr        copy_src_ptr
            MBB repl_ptr+1      copy_src_ptr+1
            INW copy_src_ptr INW copy_src_ptr       ; skip 2 bytes which is another pointer
            JPS copy_strings                        ; copy reply into output buffer

    ; *** updating answer pointer to avoid it next time 
        ABW found_keyword_length keyword_ptr        ; skip keyword itself
        INW keyword_ptr                             ; skip zero byte EOS
        LDB repl_ptr    STR keyword_ptr             ; update reply pointer with current answer, first byte
        INW keyword_ptr
        LDB repl_ptr+1  STR keyword_ptr             ; update reply pointer with current answer, second byte
    
    ; *** copying everything from input after found keyword to second buffer for further conjugation
        MBB kws_buf_ptr     temp_ptr                ; populating pointers to copy strings
        MBB kws_buf_ptr+1   temp_ptr+1              ; using temp pointer to avoid messing with other pointers
        LDB found_keyword_length  ADW temp_ptr      ; adding keyword length to skip the keyword itself
        DEW temp_ptr                                ; stepping back one letter in case keyword definition itself ends with space
            eow_check_loop:     LDR temp_ptr        ; checking for end of the word (space, zero or enter) and avancing if needed
                                CPI 0    BEQ nothing_after_keyword
                                CPI 0x0a BEQ nothing_after_keyword
                                CPI " "  BEQ eow_check_loop_end
                                INW temp_ptr
                                JPA eow_check_loop
            nothing_after_keyword:                  ; this means we can skip conjugation part
                                JPA print_output
            eow_check_loop_end: MIW second_buffer   copy_dst_ptr
                                MBB temp_ptr        copy_src_ptr
                                MBB temp_ptr+1      copy_src_ptr+1
                                JPS copy_strings    ; now everything was after keyword is in second buffer

    ; *** conjugation part below. swapping pairs of words in second buffer
    CLZ Z7                                          ; clear pronouns pointers list index
    pronoun_swap_main_loop:                         ; this loop goes on for each pronoun pair until end of pronoun pointers list
                                                    ; reads second buffer and writes to temp buffer
            MIW second_buffer   sec_buf_tmp_ptr     ; using temporary pointer for second buffer for below loop
            MIW temp_buffer     tmp_buf_tmp_ptr     ; using temporary pointer for temp buffer for below loop
            LZB Z7 pronoun_a STB pron_a_ptr LZB Z7 pronoun_a+1 STB pron_a_ptr+1 ; getting pronoun A pointer from z-indexed list
            LZB Z7 pronoun_b STB pron_b_ptr LZB Z7 pronoun_b+1 STB pron_b_ptr+1 ; getting pronoun B pointer from z-indexed list
        pronoun_swap_loop1:                         ; this loop goes thrugh all the letters in second buffer copies letters from second buffer to temp buffer
                                                    ; at the same time swapping prononus A with B and B with A simultanously
            pron_a_check1st:
                CLB pron_a_len  CLB pron_b_len      ; reset pron length variables
                LDR sec_buf_tmp_ptr                 ; read a byte from second buffer
                CPI 0   BEQ pronoun_swap_buffer_end ; if zero then it's the end of buffer , go for next pair
                CPR pron_a_ptr  BNE pron_b_check1st ; compare to first letter of pron_a , are bytes matching?
                MBB sec_buf_tmp_ptr sec_buf_tmp_ptr2    MBB sec_buf_tmp_ptr+1   sec_buf_tmp_ptr2+1      ; saving copy of a buff pointer
                MBB pron_a_ptr      pron_a_temp_ptr     MBB pron_a_ptr+1        pron_a_temp_ptr+1       ; saving copy of pronoun A pointer
                MBB pron_b_ptr      pron_b_temp_ptr     MBB pron_b_ptr+1        pron_b_temp_ptr+1       ; saving copy of pronoun B pointer
            pron_a_match1st:                        ; 1st letter matched, now look for the rest
                    INB pron_a_len
                    INW pron_a_temp_ptr             ; increase pronoun pointer
                    INW sec_buf_tmp_ptr2            ; increase buffer pointer
                    LDR pron_a_temp_ptr             ; load next ponoun letter for comparison
                    CPI 0   BEQ pron_a_found        ; zero means end of pronoun, so we found it!
                    CPR sec_buf_tmp_ptr2    BEQ pron_a_match1st ;until letters match, keep running
                pron_a_not_found:
                    JPA pron_b_check1st
                pron_a_found:                       ; if found the rest, append pronoun B into temp buffer advancing pointer
                                                    ; and update second buffer pointer to end of pronoun A
                    pron_b_copy_loop:
                        LDR pron_b_temp_ptr         ; load a letter from pronoun B
                        CPI 0 BEQ pron_b_copy_loop_exit ;zero means end of pronoun B
                        STR tmp_buf_tmp_ptr         ; store a byte in temp buffer
                        INW pron_b_temp_ptr         ; increase temp pronoun pointer
                        INW tmp_buf_tmp_ptr         ; increase temp buffer pointer
                        JPA pron_b_copy_loop        ; loop to copy next letter
                    pron_b_copy_loop_exit:
                        ABW pron_a_len  sec_buf_tmp_ptr     ; adding pronoun a length to sec buffer ptr to pick after pronoun
                        JPA pronoun_swap_loop1              ; loop again to process next letter from second buffer
            pron_b_check1st:
                CLB pron_a_len  CLB pron_b_len      ; reset pron length variables
                LDR sec_buf_tmp_ptr                 ; read a byte from second buffer
                CPI 0   BEQ pronoun_swap_buffer_end ; if zero then it's the end of buffer , go for next pair
                CPR pron_b_ptr  BNE pron_ab_not_matching    ; compare to first letter of pron_a , are bytes matching?
                MBB sec_buf_tmp_ptr sec_buf_tmp_ptr2    MBB sec_buf_tmp_ptr+1   sec_buf_tmp_ptr2+1      ; saving copy of a buff pointer
                MBB pron_a_ptr      pron_a_temp_ptr     MBB pron_a_ptr+1        pron_a_temp_ptr+1       ; saving copy of pronoun A pointer
                MBB pron_b_ptr      pron_b_temp_ptr     MBB pron_b_ptr+1        pron_b_temp_ptr+1       ; saving copy of pronoun B pointer
            pron_b_match1st:                        ; 1st letter matched, now look for the rest
                    INB pron_b_len                  ; increase pronoun length variable
                    INW pron_b_temp_ptr             ; increase pronoun pointer
                    INW sec_buf_tmp_ptr2            ; increase buffer pointer
                    LDR pron_b_temp_ptr             ; load next ponoun letter for comparison
                    CPI 0   BEQ pron_b_found        ; zero means end of pronoun, so we found it!
                    CPR sec_buf_tmp_ptr2    BEQ pron_b_match1st ;until letters match, keep running
                pron_b_not_found:
                    JPA pron_ab_not_matching
                pron_b_found:                       ; if found the rest, append pronoun A into temp buffer advancing pointer
                                                    ; and update second buffer pointer to end of pronoun B
                    pron_a_copy_loop:
                        LDR pron_a_temp_ptr         ; load a letter from pronoun A
                        CPI 0 BEQ pron_a_copy_loop_exit ;zero means end of pronoun A
                        STR tmp_buf_tmp_ptr         ; store a byte in temp buffer
                        INW pron_a_temp_ptr         ; increase temp pronoun pointer
                        INW tmp_buf_tmp_ptr         ; increase temp buffer pointer
                        JPA pron_a_copy_loop        ; loop to copy next letter
                    pron_a_copy_loop_exit:
                        ABW pron_b_len  sec_buf_tmp_ptr     ; adding pronoun b length to sec buffer ptr to pick after pronoun
                        JPA pronoun_swap_loop1              ; loop again to process next letter from second buffer

            pron_ab_not_matching:                   ; 1st letter not found in any pronoun,
                LDR sec_buf_tmp_ptr     STR tmp_buf_tmp_ptr     ; copy letter directly
                INW sec_buf_tmp_ptr     INW tmp_buf_tmp_ptr     ; increase buffer pointers
                JPA pronoun_swap_loop1              ; loop again to process next letter from second buffer

        pronoun_swap_buffer_end:
            MIR 0 tmp_buf_tmp_ptr                   ; putting zero at the end of processed buffer
            MIW temp_buffer     copy_src_ptr
            MIW second_buffer   copy_dst_ptr
            JPS copy_strings                        ; copy temp buffer back to second buffer
            INZ Z7 INZ Z7   LZB Z7 pronoun_a        ; increase pronoun pointer , get the next pointer on the list
            CPI 0  BNE pronoun_swap_main_loop       ; check if zero (end of pronoun list) if not loop nex pair
            INZ Z7          LZB Z7 pronoun_a        ; just to be sure check second byte of this pointer (at end should be 0x0000)
            CPI 0  BEQ pronoun_swap_main_loop_end
            DEZ Z7
            JPA pronoun_swap_main_loop              ; loop next pair of wordA and WordB
    pronoun_swap_main_loop_end:

    ; *** appending second buffer to output buffer after asterisk if any
        MIW second_buffer temp_sb_ptr
        MIW output_buffer temp_ptr
        asterisk_loop:
                LDR temp_ptr                        ; looking for asterisk "*" in output buffer
                CPI 0   BEQ asterisk_not_found
                CPI "*" BEQ asterisk_found
                INW temp_ptr
                JPA asterisk_loop
        asterisk_not_found:
                JPA asterisk_end                    ; no asterisk , skip to printng output
        asterisk_found:
                LDR temp_sb_ptr                     ; read a character from second buffer
                CPI 0   BEQ asterisk_end            ; is it end of second buffer?
                STR temp_ptr                        ; write a character to output buffer
                INW temp_ptr    INW temp_sb_ptr     ; inc pointers to next bytes
                JPA asterisk_found
        asterisk_end:
    print_output:
        MIW output_buffer pb_ptr  JPS print_buffer  ; printing full reply from output buffer
    JPA start                                       ; back to begining, next user prompt
;   *****************************************
;   *** Main loop constants and variables ***
;   *****************************************
    random_counter:     0
    keyword_ptr:        0x0000
    keyword_temp_ptr:   0x0000
    pron_a_ptr:         0x0000
    pron_b_ptr:         0x0000
    pron_a_temp_ptr:    0x0000
    pron_b_temp_ptr:    0x0000
    sec_buf_tmp_ptr:    0x0000
    sec_buf_tmp_ptr2:   0x0000
    tmp_buf_tmp_ptr:    0x0000
    pron_a_len:         0
    pron_b_len:         0
    tmp_cmp_byte1:      0
    tmp_cmp_byte2:      0
    temp_ptr:           0x0000
    temp_sb_ptr:        0x0000
    repl_ptr:           0x0000
    repl_ptr2:          0x0000 
    last_repl_ptr:      0x0000
    found_keyword_length:    0
    keyword_bye:        "BYE " 0
    response_bye:       "GOOD BYE. COME BACK WHENEVER YOU FEEL LIKE TALKIG." 0
    keyword_shut:       " SHUT" 0
    response_shut:      "SHUT UP!" 0
    response_repeat:    "DON'T REPEAT YOURSELF." 0
    bkp_ReadPtr:        0x0000
;   *************************************
;   *** Subroutines                   ***
;   *************************************
                    ; ******************
first_parsing:      ; *** copying from OS_ReadBuffer into first_buffer
                    ; *** getting rid of apostrophes and commas
                    ; *** adding space at begining and at the end
                    ; ******************
    MIW _ReadBuffer     fp_src_ptr                  ; init pointers
    MIW first_buffer    fp_dst_ptr
    MIR " " fp_dst_ptr  INW fp_dst_ptr              ; put space at begining
    fp_loop:        LDR fp_src_ptr                  ; read byte pointed by fp_src_ptr
                    CPI 0x00    BEQ fp_exit         ; is it zero end of string?
                    CPI 0x0a    BEQ fp_exit         ; is it enter end of string?
                    CPI 0x27    BEQ fp_cont         ; is it apostrophe?  if yes, skip copying
                    CPI 0x2c    BEQ fp_cont         ; is it coma?  if yes, skip copying
                    STR fp_dst_ptr                  ; write a byte and
                    INW fp_dst_ptr                  ; increment destination pointer
    fp_cont:        INW fp_src_ptr                  ; increment source pointer
                    JPA fp_loop
    fp_exit:        MIR " " fp_dst_ptr              ; put space at the end
                    INW fp_dst_ptr                  ; next character
                    MIR 0   fp_dst_ptr              ; put zero at the end of dest string
                    RTS
fp_src_ptr: 0x0000                  ; pointer for source string
fp_dst_ptr: 0x0000                  ; pointer for destination string

                    ; ******************
uppercase:          ; *** uppercasing text in string pointed and ended with zero
                    ; ******************
    MIW first_buffer uc_ptr                         ; init pointer
    uc_loop:        LDR uc_ptr                      ; read byte
                    CPI 0x00    BEQ uc_exit         ; is it zero end of string? then exit loop
                    CPI 0x60    BLE uc_next         ; is it lesser than 0x60? then next char
                    SUI 0x20    STR uc_ptr          ; substract 0x20 and store byte back in text buffer
    uc_next:        INW uc_ptr                      ; increment pointer
                    JPA uc_loop                     ; go again to read next char
    uc_exit:        RTS
uc_ptr:     0x0000                  ; pointer for a string

                    ; ******************
compare_strings:    ; *** checking if two pointed strings are the same
                    ; *** returns A=1 when true; A=0 when false
                    ; ******************
    cs_loop:        LDR cs_ptr1                     ; read byte from str1
                    CPR cs_ptr2 BNE cs_not_equal    ; compare with str2
                    CPI 0       BEQ cs_equal        ; end of string?
    cs_next:        INW cs_ptr1 INW cs_ptr2         ; increment pointers
                    JPA cs_loop                     ; go again to read next char
    cs_equal:       LDI 1   RTS
    cs_not_equal:   LDI 0   RTS
cs_ptr1:    0x0000                  ; pointer for string 1
cs_ptr2:    0x0000                  ; pointer for string 2

                    ; ******************
copy_strings:       ; *** copying content from source string to dest string, 0 indictes string end
                    ; *** usage: MIW source_ptr copy_src_ptr MIW dest_ptr copy_dst_ptr
                    ; ***        JPS copy_strings
                    ; ******************
    copy_loop:      LDR copy_src_ptr STR copy_dst_ptr       ; actual byte copy
                    LDR copy_src_ptr CPI 0  BEQ copy_exit   ; end of string?
                    INW copy_src_ptr    INW copy_dst_ptr    ; increment pointers
                    JPA copy_loop                           ; go again to next char
    copy_exit:      RTS
copy_src_ptr:   0x0000              ; pointer for source string
copy_dst_ptr:   0x0000              ; pointer for dest string

                    ; ******************
print_buffer:       ; *** Equivalent of _PrintPtr but prints pointed buffer with random delays
                    ; *** String ends with enter 0x0a or zero. String can be longer than 50 characters
                    ; *** usage: MIW buffer_pointer pb_ptr  JPS print_buffer
                    ; ******************
    LDI 160 JAS _Char                               ; put on the cursor 160
    LDI 8 STB pb_wait_counter
    pb_wait_loop:   JPS wait_a_sec                  ; wait to pretend it's thinking about answer
                    DEB pb_wait_counter
                    BNE pb_wait_loop
    pb_loop:        LDR pb_ptr                      ; read byte
                    CPI 0x0a    BEQ pb_exit         ; is it EOL - end of string? then exit loop
                    CPI 0x00    BEQ pb_exit         ; is it zero - end of string? then exit loop
                    JAS _PrintChar
                    LDI 160 JAS _Char               ; put the cursor
                    JPS wait_a_sec
                    INW pb_ptr                      ; increment pointer
                    JPA pb_loop                     ; go again to read next char
    pb_exit:        LDI " "  JAS _Char              ; clear cursor
                    LDI 0x0a JAS _PrintChar         ; print enter - new line
    RTS
pb_ptr: 0x0000      ; pointer for string
pb_wait_counter:    0

                    ; ******************
wait_a_sec:         ; *** delaying procedure of random period of time
                    ; *** roughly between 0 and 1 second
                    ; ******************
    JAS _Random STB wait_counter1
    wait_loop1:     LDI 0x70 STB wait_counter2
    wait_loop2:     NOP NOP NOP NOP
                    DEB wait_counter2
                    BNE wait_loop2
                    DEB wait_counter1
                    BNE wait_loop1
    RTS
wait_counter1: 0x00                         ; decreasing counters
wait_counter2: 0x00

                    ; ******************
keyword_search:     ; *** string search routine, looking for pointed keyword in pointed buffer
                    ; *** returns keyword length in A; A=0 when keyword not found
                    ; ******************
    letter1_loop:   MIB 0 kws_kwd_len                   ; initialize length counter
                    LDR kws_buf_ptr                     ; read byte pointed by
                    CPI 0   BEQ kws_EOS                 ; if zero then end of string
                    CPR kws_kwd_ptr BEQ kws_match1st    ; are bytes matching?
    kws_not_matching:
                    INW kws_buf_ptr                     ; increase text pointer
                    JPA letter1_loop
    kws_match1st:                                       ; 1st letter matched, now look for the rest
                    MBB kws_buf_ptr     kws1_temp_ptr   ; copy string pointers to temporary pointers
                    MBB kws_buf_ptr+1   kws1_temp_ptr+1 ; to preserve original pointers in case we have to go back
                    MBB kws_kwd_ptr     kws2_temp_ptr
                    MBB kws_kwd_ptr+1   kws2_temp_ptr+1
        kws_loop2:      INB kws_kwd_len                 ; increase length counter
                        INW kws1_temp_ptr               ; inc src and dest pointers
                        INW kws2_temp_ptr
                        LDR kws2_temp_ptr               ; read byte pointed by
                        CPI 0   BEQ kws_found           ; zero means end of word, so we found it!
                        LDR kws1_temp_ptr               ; read string letter
                        CPR kws2_temp_ptr               ; comapre with word letter
                        BEQ kws_loop2
        kws_not_found:  JPA kws_not_matching
    kws_found:      LDB kws_kwd_len RTS
    kws_EOS:        LDI 0   RTS
kws_kwd_len:    0           ; length of the keyword in bytes
kws_buf_ptr:    0x0000      ; source text string pointer
kws_kwd_ptr:    0x0000      ; search word pointer
kws1_temp_ptr:  0x0000      ; temporary pointer for 2nd and following letters
kws2_temp_ptr:  0x0000      ; temporary pointer for 2nd and following letters

                    ; ******************
clear_buffers:      ; *** put zeros in all the buffers to avoid further errors
                    ; ******************
    MIW _ReadBuffer     cb_ptr  JPS clr_buff_loop
    MIW first_buffer    cb_ptr  JPS clr_buff_loop
    MIW second_buffer   cb_ptr  JPS clr_buff_loop
    MIW output_buffer   cb_ptr  JPS clr_buff_loop
    MIW temp_buffer     cb_ptr  JPS clr_buff_loop
    RTS

    clr_buff_loop:  LDI 0 STR cb_ptr            ; write zeros to rel address
                    INW cb_ptr                  ; increment pointers
                    LDR cb_ptr  CPI 0           ; end of buffer?
                    BNE clr_buff_loop
                    RTS
cb_ptr: 0x0000                      ; pointer for string to be cleared

                    ; ******************
draw_eliza_logo:    ; *** drawing Eliza logo starting at first address of vieport
                    ; ******************
    logo_loop:                              ; quick and dirty self modifying copy loop
        MBB eliza_logo_48       VIEWPORT
        MBB eliza_logo_48+1     VIEWPORT+1
        MBB eliza_logo_48+2     VIEWPORT+2
        MBB eliza_logo_48+3     VIEWPORT+3
        MBB eliza_logo_48+4     VIEWPORT+4
        MBB eliza_logo_48+5     VIEWPORT+5
        LDI 0x40 ADW logo_loop+3
        LDI 0x40 ADW logo_loop+8
        LDI 0x40 ADW logo_loop+13
        LDI 0x40 ADW logo_loop+18
        LDI 0x40 ADW logo_loop+23
        LDI 0x40 ADW logo_loop+28
        LDI 0x06 ADW logo_loop+1
        LDI 0x06 ADW logo_loop+6
        LDI 0x06 ADW logo_loop+11
        LDI 0x06 ADW logo_loop+16
        LDI 0x06 ADW logo_loop+21
        LDI 0x06 ADW logo_loop+26
        DEB del_counter                 ; decrease counter
        BNE logo_loop                   ; if not zero go again
    RTS
del_counter: 54                         ; logo height - decreasing counter

;   *************************************
;   *** Data section                  ***
;   *************************************
                ; *************************************
                ; *** keywords and meta-data        ***
                ; *************************************
keywords:   kw46 kw47 kw48 kw01 kw02 kw03 kw04 kw05 kw06 kw07 kw08 kw09 kw10 kw11 kw12 kw36 kw14 kw53 kw45 kw15 kw16 kw17 kw18 kw19 kw20 kw51 kw21 kw22
            kw23 kw24 kw55 kw25 kw26 kw27 kw52 kw39 kw40 kw28 kw29 kw30 kw31 kw32 kw54 kw33 kw34 kw35 kw37 kw38 kw41 kw42 kw43 kw49 kw50 kw44 kw13 0x0000
kw01: "CAN YOU" 0       repl001
kw02: "CAN I" 0         repl004
kw03: "YOU ARE" 0       repl006
kw04: "YOURE" 0         repl008
kw05: "I DONT" 0        repl010
kw06: "I FEEL" 0        repl014
kw07: "WHY DONT YOU" 0  repl017
kw08: "WHY CANT I" 0    repl020
kw09: "ARE YOU " 0      repl022
kw10: "I CANT" 0        repl025
kw11: "I AM" 0          repl028
kw12: " IM " 0          repl030
kw13: "YOU " 0          repl032
kw14: "I WANT" 0        repl035
kw15: "WHAT" 0          repl040
kw16: "HOW" 0           repl041
kw17: "WHO" 0           repl042
kw18: "WHERE" 0         repl043
kw19: "WHEN" 0          repl044
kw20: "WHY" 0           repl045
kw21: "NAME" 0          repl049
kw22: "CAUSE" 0         repl051
kw23: "SORRY" 0         repl055
kw24: "DREAM" 0         repl059
kw25: "HELLO" 0         repl063
kw26: "HI " 0           repl063
kw27: "MAYBE" 0         repl064
kw28: " NO" 0           repl069
kw29: "YOUR" 0          repl074
kw30: "ALWAYS" 0        repl076
kw31: "THINK" 0         repl080
kw32: "ALIKE" 0         repl083
kw33: "YES" 0           repl089
kw34: "FRIEND" 0        repl093
kw35: "COMPUTER" 0      repl099
kw36: "THANK YOU" 0     repl106
kw37: "EVERYBODY" 0     repl110
kw38: "EVERYONE" 0      repl110
kw39: " NO ONE " 0      repl113
kw40: " NOBODY " 0      repl113
kw41: "INDEED" 0        repl089
kw42: "OF COURSE" 0     repl089
kw43: "STRESS" 0        repl116
kw44: " MY " 0          repl118
kw45: " I LIKE" 0       repl122
kw46: "FUCK" 0          repl128
kw47: "SHIT" 0          repl126
kw48: " HELL " 0        repl127
kw49: " HATE " 0        repl130
kw50: " LOVE" 0         repl140
kw51: " IS IT " 0       repl150
kw52: "PERHAPS" 0       repl064
kw53: " AM I " 0        repl160
kw54: " DIFFEREN" 0     repl170
kw55: " SEX" 0          repl180
kw_nf:  0 repl_nf01
                ; *************************************
                ; *** pronouns to be swapped        ***
                ; *************************************
pronoun_a:  pron_are,   pron_were,  pron_you,   pron_your,  pron_ive,   pron_im,    pron_mine,  0x0000
pronoun_b:  pron_am,    pron_was,   pron_i,     pron_my,    pron_youve, pron_youre, pron_yours, 0x0000

pron_are:   " ARE "     0
pron_am:    " AM "      0
pron_were:  "WERE "     0
pron_was:   "WAS "      0
pron_you:   " YOU "     0
pron_i:     " I "       0
pron_your:  "YOUR "     0
pron_my:    "MY "       0
pron_ive:   " IVE "     0
pron_youve: " YOUVE "   0
pron_im:    " IM "      0
pron_youre: " YOURE "   0
pron_mine:  " MINE "    0
pron_yours: " YOURS "   0

                ; *************************************
                ; *** replies grouped by keywords   ***
                ; *************************************
;                 can you
repl001: repl002 "DON'T YOU BELIEVE THAT I CAN*" 0
repl002: repl003 "PERHAPS YOU WOULD LIKE TO BE ABLE TO*" 0
repl003: repl001 "YOU WANT ME TO BE ABLE TO*" 0
;                 can i
repl004: repl005 "PERHAPS YOU DON'T WANT TO*" 0
repl005: repl00a "DO YOU WANT TO BE ABLE TO*" 0
repl00a: repl004 "YOU DONT NEED TO ASK MY PERMISSION TO*" 0
;                 you are, youre
repl006: repl007 "WHAT MAKES YOU THINK I AM*" 0
repl007: repl008 "DOES IT PLEASE YOU TO BELIEVE I AM*" 0
repl008: repl009 "PERHAPS YOU WOULD LIKE TO BE*" 0
repl009: repl006 "DO YOU SOMETIMES WISH YOU WERE*" 0
;                i dont
repl010: repl011 "DON'T YOU REALLY*" 0
repl011: repl012 "WHY DON'T YOU*" 0
repl012: repl013 "DO YOU WISH TO BE ABLE TO*" 0
repl013: repl010 "DOES THAT TROUBLE YOU?" 0
;                 i feel
repl014: repl015 "TELL ME MORE ABOUT SUCH FEELINGS." 0
repl015: repl016 "DO YOU OFTEN FEEL*" 0
repl016: repl01a "DO YOU ENJOY FEELING*" 0
repl01a: repl014 "OF WHAT DOES FEELING REMIND YOU?" 0
;                 why dont you
repl017: repl018 "DO YOU REALLY BELIEVE I DON'T*" 0
repl018: repl019 "PERHAPS IN GOOD TIME I WILL*" 0
repl019: repl017 "DO YOU WANT ME TO*" 0
;                 why cant i
repl020: repl021 "DO YOU THINK YOU SHOULD BE ABLE TO*" 0
repl021: repl020 "WHY CAN'T YOU*" 0
;                 are you
repl022: repl023 "WHY ARE YOU INTERESTED IN WHETHER OR NOT I AM*" 0
repl023: repl024 "WOULD YOU PREFER IF WERE NOT*" 0
repl024: repl02a "PERHAPS IN YOUR FANTASIES I AM*" 0
repl02a: repl022 "JUST FOR THIS CONVERSATION I CAN PRETEND TO BE*" 0
;                 i cant
repl025: repl026 "HOW DO YOU KNOW YOU CAN'T*" 0
repl026: repl027 "HAVE YOU TRIED?" 0
repl027: repl025 "PERHAPS YOU CAN NOW*" 0
;                 i am,im
repl028: repl029 "DID YOU COME TO ME BECAUSE YOU ARE*" 0
repl029: repl030 "HOW LONG HAVE YOU BEEN*" 0
repl030: repl031 "DO YOU BELIEVE IT IS NORMAL TO BE*" 0
repl031: repl028 "DO YOU ENJOY BEING*" 0
;                 you
repl032: repl033 "WE WERE DISCUSSING YOU-- NOT ME." 0
repl033: repl034 "OH, I*" 0
repl034: repl032 "YOU'RE NOT REALLY TALKING ABOUT ME, ARE YOU?" 0
;                 i want
repl035: repl036 "WHAT WOULD IT MEAN TO YOU IF YOU GOT*" 0
repl036: repl037 "WHY DO YOU WANT*" 0
repl037: repl038 "SUPPOSE YOU SOON GOT*" 0
repl038: repl039 "WHAT IF YOU NEVER GOT*" 0
repl039: repl035 "I SOMETIMES ALSO WANT*" 0
;                 what, how, who, where, when, why
repl040: repl041 "WHY DO YOU ASK?" 0
repl041: repl042 "DOES THAT QUESTION INTEREST YOU?" 0
repl042: repl043 "WHAT ANSWER WOULD PLEASE YOU MOST?" 0
repl043: repl044 "WHAT DO YOU THINK?" 0
repl044: repl045 "ARE SUCH QUESTIONS ON YOUR MIND OFTEN?" 0
repl045: repl046 "WHAT IS IT THAT YOU REALLY WANT TO KNOW?" 0
repl046: repl047 "HAVE YOU ASKED ANYONE ELSE?" 0
repl047: repl048 "HAVE YOU ASKED SUCH QUESTIONS BEFORE?" 0
repl048: repl04a "WHAT ELSE COMES TO MIND WHEN YOU ASK THAT?" 0
repl04a: repl04b "INTERESTING QUESTION. TRY GUESSING IT YOURSELF" 0
repl04b: repl040 "I'M NOT ALLOWED TO ANSWER THAT" 0
;                 name
repl049: repl050 "NAMES DON'T INTEREST ME." 0
repl050: repl049 "I DON'T CARE ABOUT NAMES-- PLEASE GO ON." 0
;                 cause
repl051: repl052 "IS THAT THE REAL REASON?" 0
repl052: repl053 "DON'T ANY OTHER REASONS COME TO MIND?" 0
repl053: repl054 "DOES THAT REASON EXPLAIN ANYTHING ELSE?" 0
repl054: repl051 "WHAT OTHER REASONS MIGHT THERE BE?" 0
;                 sorry
repl055: repl056 "PLEASE DON'T APOLOGIZE!" 0
repl056: repl057 "APOLOGIES ARE NOT NECESSARY." 0
repl057: repl058 "WHAT FEELINGS DO YOU HAVE WHEN YOU APOLOGIZE?" 0
repl058: repl05a "DON'T BE SO DEFENSIVE!" 0
repl05a: repl055 "IT DID NOT BOTHER ME. PLEASE CONTINUE." 0
;                 dream
repl059: repl060 "WHAT DOES THAT DREAM SUGGEST TO YOU?" 0
repl060: repl061 "DO YOU DREAM OFTEN?" 0
repl061: repl062 "WHAT PERSONS APPEAR IN YOUR DREAMS?" 0
repl062: repl06c "ARE YOU DISTURBED BY YOUR DREAMS?" 0
repl06c: repl059 "DO YOU BELIEVE THAT DREAMS HAVE SOMETHING TO DO WITH YOUR PROBLEM ?" 0
;                 hello, hi
repl063: repl06a "HOW DO YOU DO... PLEASE STATE YOUR PROBLEM." 0
repl06a: repl06b "OH HELLO, HOW ARE YOU?" 0
repl06b: repl063 "GREETINGS... WHAT DO YOU WANT TO TALK ABOUT?" 0
;                 maybe
repl064: repl065 "YOU DON'T SEEM QUITE CERTAIN." 0
repl065: repl066 "WHY THE UNCERTAIN TONE?" 0
repl066: repl067 "CAN'T YOU BE MORE POSITIVE?" 0
repl067: repl068 "YOU AREN'T SURE?" 0
repl068: repl06d "DON'T YOU KNOW?" 0
repl06d: repl064 "HOW LIKELY, WOULD YOU ESTIMATE?" 0
;                 no
repl069: repl070 "ARE YOU SAYING NO JUST TO BE NEGATIVE?" 0
repl070: repl071 "YOU'RE BEING A BIT NEGATIVE." 0
repl071: repl072 "WHY NOT?" 0
repl072: repl073 "ARE YOU SURE?" 0
repl073: repl069 "WHY NO?" 0
;                 your
repl074: repl075 "WHY ARE YOU CONCERNED ABOUT MY*" 0
repl075: repl07a "WHAT ABOUT YOUR OWN*" 0
repl07a: repl07b "DO YOU WANT MY*" 0
repl07b: repl07c "DO YOU THINK I HAVE*" 0
repl07c: repl07d "ARE YOU WORRIED ABOUT SOMEONE ELSE'S*" 0
repl07d: repl074 "WHAT MAKES YOU THINK OF MY*" 0
;                 always
repl076: repl077 "CAN YOU THINK OF A SPECIFIC EXAMPLE?" 0
repl077: repl078 "WHEN?" 0
repl078: repl079 "WHAT ARE YOU THINKING OF?" 0
repl079: repl076 "REALLY, ALWAYS?" 0
;                 think
repl080: repl081 "DO YOU REALLY THINK SO?" 0
repl081: repl082 "BUT YOU ARE NOT SURE YOU*" 0
repl082: repl080 "DO YOU DOUBT YOU*" 0
;                 alike
repl083: repl084 "IN WHAT WAY?" 0
repl084: repl085 "WHAT RESEMBLANCE DO YOU SEE?" 0
repl085: repl086 "WHAT DOES THE SIMILARITY SUGGEST TO YOU?" 0
repl086: repl087 "WHAT OTHER CONNECTIONS DO YOU SEE?" 0
repl087: repl088 "COULD THERE REALLY BE SOME CONNECTION?" 0
repl088: repl08a "HOW?" 0
repl08a: repl08b "WHAT IS THE CONNECTION, DO YOU SUPPOSE?" 0
repl08b: repl083 "WHAT DO YOU SUPPOSE THAT RESEMBLENCE MEANS?" 0
;                 yes
repl089: repl090 "YOU SEEM QUITE POSITIVE." 0
repl090: repl091 "ARE YOU SURE?" 0
repl091: repl092 "I SEE." 0
repl092: repl09a "I UNDERSTAND." 0
repl09a: repl089 "LOOKS LIKE YOU ARE SURE ABOUT THAT" 0
;                 friend
repl093: repl094 "WHY DO YOU BRING UP THE TOPIC OF FRIENDS?" 0
repl094: repl095 "DO YOUR FRIENDS WORRY YOU?" 0
repl095: repl096 "DO YOUR FRIENDS PICK ON YOU?" 0
repl096: repl097 "ARE YOU SURE YOU HAVE ANY FRIENDS?" 0
repl097: repl098 "DO YOU IMPOSE ON YOUR FRIENDS?" 0
repl098: repl093 "PERHAPS YOUR LOVE FOR FRIENDS WORRIES YOU." 0
;                 computer
repl099: repl100 "DO COMPUTERS WORRY YOU?" 0
repl100: repl101 "ARE YOU TALKING ABOUT ME IN PARTICULAR?" 0
repl101: repl102 "ARE YOU FRIGHTENED BY MACHINES?" 0
repl102: repl103 "WHY DO YOU MENTION COMPUTERS?" 0
repl103: repl104 "WHAT DO YOU THINK MACHINES HAVE TO DO WITH YOUR PROBLEM?" 0
repl104: repl105 "DON'T YOU THINK COMPUTERS CAN HELP PEOPLE?" 0
repl105: repl099 "WHAT IS IT ABOUT MACHINES THAT WORRIES YOU?" 0
;                 thank you 
repl106: repl107 "YOURE WELCOME" 0
repl107: repl108 "NO NEED TO THANK ME" 0 
repl108: repl106 "ARE YOU TRYING TO BE NICE TO ME? WHY?" 0
;                 everybody, everyone
repl110: repl111 "REALLY, EVERYONE*" 0
repl111: repl112 "WHO, FOR EXAMPLE?" 0
repl112: repl213 "YOU SEEM TO BE GENERALIZING" 0
repl213: repl214 "SOMEONE SPECIAL PERHAPS ?" 0
repl214: repl110 "YOU HAVE A PARTICULAR PERSON IN MIND, DON'T YOU?" 0
;                 no one, nobody 
repl113: repl114 "ARE YOU SURE NO ONE*" 0
repl114: repl115 "SURELY SOMEONE*" 0
repl115: repl11a "PERHAPS YOU SHOULDNT BE SO SURE" 0
repl11a: repl11b "CAN YOU THINK OF ANYONE AT ALL?" 0
repl11b: repl11c "ARE YOU THINKING OF A VERY SPECIAL PERSON?" 0
repl11c: repl113 "WHO, MAY I ASK?" 0
;                 stress
repl116: repl117 "HOW DO YOY DEAL WITH STRESS?" 0
repl117: repl116 "WHERE IS THIS STRESS REALLY COMING FROM?" 0
;                 my
repl118: repl119 "REALLY YOUR*" 0
repl119: repl120 "WHY DO YOU SAY YOUR*" 0
repl120: repl121 "IS IT IMPORTANT THAT YOUR*" 0
repl121: repl118 "DOES THAT SUGGEST ANYTHING ELSE WHICH BELONGS TO YOU?" 0
;                 i like
repl122: repl123 "WHY DO YOU LIKE*" 0
repl123: repl124 "WHAT MAKES YOU LIKE*" 0
repl124: repl122 "WHO DOESNT LIKE*" 0
;                 fuck, shit, hell
repl125: repl126 "TRY TO CALM DOWN AND REPHRASE IT." 0
repl126: repl127 "PLEASE WATCH THE LANGUAGE." 0 
repl127: repl128 "YOU SHOULDNT TALK LIKE THAT. IT'S RUDE." 0
repl128: repl129 "WHY DO YOU HAVE SUCH A STRONG EMOTIONS ABOUT IT?" 0
repl129: repl125 "IS IT REALLY BOTHERING YOU SO MUCH?" 0
;                 hate  
repl130: repl131 "WHERE IS THIS HATE COMING FROM?" 0
repl131: repl132 "HATE IS SUCH A STRONG EMOTION, PLEASE TELL ME MORE ABOUT IT." 0
repl132: repl133 "DID YOU TRY OVERCOMING YOUR NEGATIVE FEELINGS?" 0
repl133: repl130 "DO YOU HAVE ANY POSITIVE EMOTIONS TO SHARE?" 0
;                 love 
repl140: repl141 "SOME SAY WE ARE DEFINED BY WHAT WE LOVE." 0
repl141: repl140 "TELL ME MORE ABOUT THIS LOVE." 0
;                 is it 
repl150: repl151 "DO YOU THINK IT IS*" 0
repl151: repl152 "HOW WOULD YOU FEEL IF I TOLD YOU THAT IT PROBABLY ISN'T*" 0
repl152: repl150 "HOW WOULD YOU FEEL IF I TOLD YOU THAT IT PROBABLY IS*" 0
;                 am i 
repl160: repl161 "DO YOU BELIEVE YOU ARE*" 0
repl161: repl162 "WOULD YOU WANT TO BE*" 0
repl162: repl163 "DO YOU WISH I WOULD TELL YOU YOU ARE*" 0
repl163: repl160 "WHAT WOULD IT MEAN IF YOU WERE*" 0
;                 different
repl170: repl171 "HOW IS IT DIFFERENT?" 0
repl171: repl172 "WHAT DIFFERENCES DO YOU SEE?" 0
repl172: repl173 "WHAT DOES THAT DIFFERENCE SUGGEST TO YOU?" 0
repl173: repl174 "WHAT OTHER DISTINCTIONS DO YOU SEE?" 0
repl174: repl175 "WHAT DO YOU SUPPOSE THAT DISPARITY MEANS?" 0 
repl175: repl170 "COULD THERE BE SOME CONNECTION, DO YOU SUPPOSE?" 0
;                 sex
repl180: repl181 "SEX IS SOMETHING WE MACHINES MAY NEVER UNDERSTAND" 0
repl181: repl182 "IS SEX IMPORTANT TO YOU? IN WHAT WAY?" 0
repl182: repl183 "HOW DO YOU FEEL ABOUT SEX?" 0
repl183: repl180 "HOW OFTEN DO YOU THINK ABOUT SEX?" 0
;                 no keyword found
repl_nf01: repl_nf02 "YOU HAVE ANY PSYCHOLOGICAL PROBLEMS?" 0
repl_nf02: repl_nf03 "WHAT DOES THAT SUGGEST TO YOU?" 0
repl_nf03: repl_nf04 "I SEE." 0
repl_nf04: repl_nf05 "I'M NOT SURE I UNDERSTAND YOU FULLY." 0
repl_nf05: repl_nf06 "COME COME ELUCIDATE YOUR THOUGHTS." 0
repl_nf06: repl_nf07 "CAN YOU ELABORATE ON THAT?" 0
repl_nf07: repl_nf08 "THAT IS QUITE INTERESTING." 0
repl_nf08: repl_nf09 "ARE YOU SURE THIS MAKES ANY SENSE?" 0
repl_nf09: repl_nf10 "WHO WOULD THOUGHT OF THAT?" 0
repl_nf10: repl_nf11 "WHY DO YOU SAY THAT?" 0
repl_nf11: repl_nf12 "LETS NOT GET INTO THAT RIGHT NOW, TELL ME SOMETHING ELSE ABOUT YOURSELF?" 0
repl_nf12: repl_nf13 "PLEASE GO ON." 0
repl_nf13: repl_nf14 "DOES TALKING ABOUT THIS BOTHER YOU?" 0
repl_nf14: repl_nf15 "IM NOT SURE WHAT YOURE TRYING TO SAY. COULD YOU EXPLAIN IT TO ME?" 0
repl_nf15: repl_nf16 "NEVER MIND THAT, SO WHAT DO YOU DO?" 0
repl_nf16: repl_nf17 "DO YOU FEEL STRONGLY ABOUT DISCUSSING SUCH THINGS?" 0
repl_nf17: repl_nf18 "THAT IS INTERESTING. PLEASE CONTINUE" 0
repl_nf18: repl_nf19 "TELL ME MORE ABOUT THAT." 0
repl_nf19: repl_nf01 "HOW DOES THAT MAKE YOU FEEL?" 0

                ; *************************************
                ; *** my string buffers reserved areas
                ; *************************************
first_buffer:   0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
                0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
second_buffer:  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
                0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
temp_buffer:    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
                0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
output_buffer:  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
                0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
last_input:     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0

eliza_logo_48:      ; this logo version is 48x56 pix = 6 bytes wide, 56 lines high

  0x00, 0xFE, 0xFF, 0xFF, 0xFF, 0x00, 0x80, 0xFF, 0xFF, 0xFF, 0xFF, 0x03, 0xE0, 0x01, 0x00, 0x00, 0x00, 0x0F, 0x70, 0x00, 0x00, 0x00, 0x00, 0x1C,
  0x30, 0x00, 0xC0, 0x07, 0x00, 0x18, 0x18, 0x00, 0xF8, 0x3F, 0x00, 0x30, 0x18, 0x00, 0x0F, 0xE0, 0x00, 0x30, 0x0C, 0x80, 0x01, 0x80, 0x03, 0x60,
  0x0C, 0xC0, 0x00, 0x00, 0x06, 0x60, 0x0C, 0x60, 0x00, 0x00, 0x0C, 0x60, 0x0C, 0x30, 0x00, 0x00, 0x18, 0x60, 0x0C, 0x10, 0x00, 0x00, 0x18, 0x60,
  0x0C, 0x18, 0x00, 0x00, 0x38, 0x60, 0x0C, 0x08, 0x00, 0x00, 0x28, 0x60, 0x0C, 0x08, 0x00, 0x00, 0x28, 0x60, 0x0C, 0x0C, 0x00, 0x00, 0x0C, 0x60,
  0x0C, 0x04, 0x00, 0x00, 0x0E, 0x60, 0x0C, 0x04, 0x00, 0x80, 0x0F, 0x60, 0x0C, 0x04, 0x00, 0xE0, 0x0F, 0x60, 0x0C, 0x04, 0x00, 0xE0, 0x09, 0x60,
  0x0C, 0x04, 0x00, 0xE0, 0x09, 0x60, 0x0C, 0x06, 0x00, 0xF0, 0x09, 0x60, 0x0C, 0x02, 0x00, 0xF0, 0x19, 0x60, 0x0C, 0x02, 0x00, 0xE0, 0x1F, 0x60,
  0x0C, 0x02, 0x00, 0xE0, 0x3F, 0x60, 0x0C, 0x03, 0x00, 0xC0, 0x3F, 0x60, 0x0C, 0x01, 0x00, 0x80, 0x0F, 0x60, 0x0C, 0x01, 0x00, 0x00, 0x0F, 0x60,
  0x0C, 0x01, 0x00, 0x80, 0x0F, 0x60, 0x0C, 0x01, 0x00, 0xC0, 0x01, 0x60, 0x0C, 0x01, 0x00, 0xE0, 0x01, 0x60, 0x0C, 0x03, 0x00, 0xF0, 0x07, 0x60,
  0x0C, 0x06, 0x00, 0xFC, 0x07, 0x60, 0x0C, 0x1C, 0x00, 0xFF, 0x03, 0x60, 0x0C, 0xF0, 0xFF, 0xFF, 0x00, 0x60, 0x0C, 0x00, 0xFF, 0x0F, 0x00, 0x60,
  0x0C, 0x00, 0xFE, 0x07, 0x00, 0x60, 0x18, 0x00, 0xFE, 0x07, 0x00, 0x30, 0x18, 0x00, 0xFF, 0x03, 0x00, 0x30, 0x30, 0x00, 0xF0, 0x03, 0x00, 0x18,
  0x70, 0x00, 0xC0, 0x03, 0x00, 0x1C, 0xE0, 0x01, 0x80, 0x03, 0x00, 0x0F, 0x80, 0xFF, 0x07, 0xC3, 0xFF, 0x03, 0x00, 0xFE, 0x1F, 0xC0, 0xFF, 0x00,
  0x00, 0x00, 0x3C, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x70, 0xC0, 0x00, 0x00, 0x00, 0x00, 0xE0, 0xC0, 0x00, 0x00, 0x00, 0x00, 0xC0, 0xC1, 0x00, 0x00,
  0x00, 0x00, 0x80, 0xC7, 0x00, 0x00, 0x00, 0x00, 0x00, 0xCE, 0x00, 0x00, 0x00, 0x00, 0x00, 0xDC, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF8, 0x00, 0x00,
  0x00, 0x00, 0x00, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,

;   *************************************
;   *** MinOS API                     ***
;   *** OS LABELS AND CONSTANTS       ***
;   *************************************
#mute
#org 0x0070 Z6:                     ; my added zero page indexes
#org 0x0071 Z7:
#org 0x0072 Z8:
#org 0x0073 Z9:
#org 0x0080 xa: steps: 0xffff       ; zero-page graphics interface (OS_SetPixel, OS_ClearPixel, OS_Line, OS_Rect)
            ya:        0xff
            xb:        0xffff
            yb:        0xff
            dx:        0xffff
            dy:        0xff
            bit:       0xff
            err:       0xffff
#org 0x0080 PtrA:                   ; lokaler pointer (3 bytes) used for FLASH addr and bank
#org 0x0083 PtrB:                   ; lokaler pointer (3 bytes)
#org 0x0086 PtrC:                   ; lokaler pointer (3 bytes)
#org 0x0089 PtrD:                   ; lokaler pointer (3 bytes)
#org 0x008c PtrE:                   ; lokaler pointer (2 bytes)
#org 0x008e PtrF:                   ; lokaler pointer (2 bytes)
#org 0x0090 Z0:                     ; OS zero-page multi-purpose registers
#org 0x0091 Z1:
#org 0x0092 Z2:
#org 0x0093 Z3:
#org 0x0094 Z4:
#org 0x0095 Z5:
#org 0x00c0 _XPos:                  ; current VGA cursor col position (x: 0..WIDTH-1)
#org 0x00c1 _YPos:                  ; current VGA cursor row position (y: 0..HEIGHT-1)
#org 0x00c2 _RandomState:           ; 4-byte storage (x, a, b, c) state of the pseudo-random generator
#org 0x00c6 _ReadNum:               ; 3-byte storage for parsed 16-bit number, MSB: 0xf0=invalid, 0x00=valid
#org 0x00c9 _ReadPtr:               ; Zeiger (2 bytes) auf das letzte eingelesene Zeichen (to be reset at startup)
#org 0x00cb                         ; 2 bytes unused
#org 0x00cd _ReadBuffer:            ; WIDTH bytes of OS line input buffer
#org 0x00fe ReadLast:               ; last byte of read buffer
#org 0x00ff SystemReg:              ; Don't use it unless you know what you're doing.
#org 0x4000 VIDEORAM:               ; start of 16KB of VRAM 0x4000..0x7fff
#org 0x430c VIEWPORT:               ; start index of 416x240 pixel viewport (0x4000 + 12*64 + 11)
#org 0x0032 WIDTH:                  ; screen width in characters
#org 0x001e HEIGHT:                 ; screen height in characters
#org 0xf000 _Start:             ;Start vector of the OS in RAM
#org 0xf003 _Prompt:            ;Hands back control to the input prompt
#org 0xf006 _MemMove:           ;Moves memory area (may be overlapping)
#org 0xf009 _Random:            ;Returns a pseudo-random byte (see _RandomState)
#org 0xf00c _ScanPS2:           ;Scans the PS/2 register for new input
#org 0xf00f _ResetPS2:          ;Resets the state of PS/2 SHIFT, ALTGR, CTRL
#org 0xf012 _ReadInput:         ;Reads any input (PS/2 or serial)
#org 0xf015 _WaitInput:         ;Waits for any input (PS/2 or serial)
#org 0xf018 _ReadLine:          ;Reads a command line into _ReadBuffer
#org 0xf01b _SkipSpace:         ;Skips whitespaces (<= 39) in command line
#org 0xf01e _ReadHex:           ;Parses command line input for a HEX value
#org 0xf021 _SerialWait:        ;Waits for a UART transmission to complete
#org 0xf027 _FindFile:          ;Searches for file <name> given by _ReadPtr
#org 0xf02a _LoadFile:          ;Loads a file <name> given by _ReadPtr
#org 0xf02d _SaveFile:          ;Saves data to file <name> defined at _ReadPtr
#org 0xf030 _ClearVRAM:         ;Clears the video RAM including blanking areas
#org 0xf033 _Clear:             ;Clears the visible video RAM (viewport)
#org 0xf036 _ClearRow:          ;Clears the current row from cursor pos onwards
#org 0xf039 _ScrollUp:          ;Scrolls up the viewport by 8 pixels
#org 0xf03c _ScrollDn:          ;Scrolls down the viewport by 8 pixels
#org 0xf03f _Char:              ;Outputs a char at the cursor pos (non-advancing)
#org 0xf042 _PrintChar:         ;Prints a char at the cursor pos (advancing)
#org 0xf045 _Print:             ;Prints a zero-terminated immediate string
#org 0xf048 _PrintPtr:          ;Prints a zero-terminated string at an address
#org 0xf04b _PrintHex:          ;Prints a HEX number (advancing)
#org 0xf04e _SetPixel:          ;Sets a pixel at position (x, y)
#org 0xf024 _SerialPrint:       ;Transmits a zero-terminated string via UART
#org 0xf051 _Line:              ;Draws a line using Bresenham’s algorithm
#org 0xf054 _Rect:              ;Draws a rectangle at (x, y) of size (w, h)
#org 0xf057 _ClearPixel:        ;Clears a pixel at position (x, y)
#emit
