; Dummy copper just for test direct running
CopperDefault:
	dc.w	$0180,$0000
	REPT	16
	dc.w	($2c+REPTN)<<8|$1,$ff00
	dc.w	$0180,REPTN<<8
	ENDR
	REPT	16
	dc.w	($3c+REPTN)<<8|$1,$ff00
	dc.w	$0180,REPTN<<4
	ENDR
	REPT	16
	dc.w	($4c+REPTN)<<8|$1,$ff00
	dc.w	$0180,REPTN
	ENDR
	REPT	16
	dc.w	($5c+REPTN)<<8|$1,$ff00
	dc.w	$0180,REPTN<<8|REPTN<<4
	ENDR
	REPT	16
	dc.w	($6c+REPTN)<<8|$1,$ff00
	dc.w	$0180,REPTN<<8|REPTN
	ENDR
	REPT	16
	dc.w	($7c+REPTN)<<8|$1,$ff00
	dc.w	$0180,REPTN<<4|REPTN
	ENDR
	REPT	16
	dc.w	($8c+REPTN)<<8|$1,$ff00
	dc.w	$0180,REPTN<<8|REPTN<<4|REPTN
	ENDR
	dc.w	$9c01,$ff00
	dc.w	$0180,$0000
	dc.w	$ffff,$fffe
	dc.w	$ffff,$fffe
