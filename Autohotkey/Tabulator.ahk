#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

SetTitleMatchMode, 2

nInitTabs = 2	; nInitTabs, input, how many tabs should be between/before commas if everything else is empty
sCommand := ""	; puts this string at the beginning of the row, after nInitTabs tabs
nTabs = 1		; nTabs, input, how many tabs should be between/before commas if everything else is empty
nSpaces = 4		; a Tab is nSpaces spaces
nDigs = 4		; nDigs digits after decimal; for rounding
nCols = 0
sStatus = 0		;0 = unchanged
sStatus2 = 0	;0 = unchanged. Status for 4000 statuses to catch circle shadings
bAddComma	= 0	; Force add/remove comma at the line ends

; https://jacks-autohotkey-blog.com/2020/06/08/autohotkey-tooltip-command-tricks/
OnMessage(0x200,"CheckControl") ; WM_MOUSEMOVE = 0x200

return

CheckControl()
{
  MouseGetPos,,,, VarControl
  IfEqual, VarControl, Edit1
    Message := "Number of leading tabs"
  Else IfEqual, VarControl, Edit2
	Message := "A command string at the beginning"
  Else IfEqual, VarControl, Edit3
	Message := "Number of tabs between commas"
  Else IfEqual, VarControl, Edit4
    Message := "Number of digits after decimal point"
  Else IfEqual, VarControl, Edit5
    Message := "Status code string"
  Else IfEqual, VarControl, Edit6
    Message := "Status code string for 4000 statuses"
; Else IfEqual, VarControl, Edit7
;    Message := "Put comma at the end"
;  Else IfEqual, VarControl, Edit8
;    Message := "Status code string for 4000 statuses"
  Else IfEqual, VarControl, Checkbox1
    Message := ""
  ToolTip % Message
}

TabulatorGUI()
{
	global inText, nSpaces, nInitTabs, sCommand, nTabs, nDigs, sStatus, sStatus2, bAddComma

	Gui, 1: New
	Gui, 1: font, s10, Courier New
	Gui, 1: Add, Edit,        w45 h20   x5  y0 vnInitTabs	gInitTabsRecalculate,	%nInitTabs%
	Gui, 1: Add, Edit,        w45 h20  x55  y0 vsCommand	gInitTabsRecalculate,	%sCommand%
	Gui, 1: Add, Edit,        w45 h20 x105  y0 vnTabs		gTabsRecalculate, 		%nTabs%
	Gui, 1: Add, Edit,        w45 h20 x155  y0 vnDigs		gDigsRecalculate,		%nDigs%
	Gui, 1: Add, Edit,        w45 h20 x205  y0 vsStatus		gStatusRecalculate, 	%sStatus%
	Gui, 1: Add, Edit,        w45 h20 x255  y0 vsStatus2	gStatusRecalculate, 	%sStatus2%
	Gui, 1: Add, Checkbox,    x305  y0 vbAddComma Check3 CheckedGray	gStatusRecalculate, 	Comma at end

	Gui, 1: Add, Edit,       w590 r10   x5 y25 T16 WantTab vinText,			%inText%

	Gui, 1: Add, Button, default, OK
	Gui, 1: Show, x300 y200 h200 w600, Tabulator
	gosub, Reformat
	return

	ButtonOK:
	GuiClose:
		Gui, Destroy
	return

	StatusRecalculate:
		GuiControlGet, sStatus
		GuiControlGet, sStatus2
		GuiControlGet, bAddComma
		gosub Reformat
	return

	InitTabsRecalculate:
		GuiControlGet, nInitTabs
		GuiControlGet, sCommand
		gosub Reformat
	return

	TabsRecalculate:
		GuiControlGet, nTabs
		gosub Reformat
	return

	DigsRecalculate:
		GuiControlGet, nDigs
		gosub Reformat
	return

	Reformat:
		_inText := ""
		sArray := []
		sCommands := []
		maxLeadDigs := []
		maxTrailDigs := []
		nRows := 0
		iDecimalPositions := []

		sLeadingChars := "^[^.]*\.?"

		Loop, Parse, Clipboard, `n
		{
			_iRows := A_Index
			sArray[_iRows] := []
			nRows += 1

			Loop, Parse, A_LoopField, `,
			{
				_sField := A_LoopField

				if (A_Index = 1)
				{
					if (A_LoopField ~= "[a-zA-Z]")
					{
						RegExMatch(A_LoopField, "O)^\s*[a-zA-Z][a-zA-Z0-9_~]+", _temp)
						sCommands[_iRows] := _temp.Value
						_sField := RegExReplace(A_LoopField, "^\s*[a-zA-Z][a-zA-Z0-9_~]+")
						sCommands[_iRows] := RegExReplace(sCommands[_iRows], "^\s*")
					}
					else
					{
						sCommands[_iRows] := ""
					}
				}

				if (_sField ~= "\S+") > 0	;not empty
				{
					_nTrailDigs := StrLen(RegExReplace(RegExReplace(Round(_sField, nDigs), "0*\Z"), sLeadingChars))
					_nTrailDigs := _nTrailDigs < nDigs ? _nTrailDigs : nDigs

					sArray[_iRows][A_Index] := Round(RegExReplace(_sField, "^\s*"), _nTrailDigs)

					_nLeadDigs := RegExMatch(sArray[_iRows][A_Index], "\.|\Z") - 1
					maxLeadDigs[A_Index] := maxLeadDigs[A_Index] > _nLeadDigs ? maxLeadDigs[A_Index] : _nLeadDigs

					_trailDigs := StrLen(RegExReplace(sArray[_iRows][A_Index], sLeadingChars)) + (RegExMatch(sArray[_iRows][A_Index], "\.") > 0 ? 1 : 0) + 1
					maxTrailDigs[A_Index] := maxTrailDigs[A_Index] > _trailDigs ? maxTrailDigs[A_Index] : _trailDigs

					nCols := nCols > A_Index ? nCols : A_Index
				}
			}
		}

		_iPrevDecPos = 0
		_iPrevTrailDigs = 0
		Loop, %nCols%
		{
			maxTrailDigs[A_Index] :=  ceil(maxTrailDigs[A_Index] / nTabs) * nTabs
			_nSpacesToAdd := _iPrevTrailDigs + maxLeadDigs[A_Index]
			if (A_Index > 1)
			{
				_nSpacesToAdd := _nSpacesToAdd > nTabs * nSpaces ? _nSpacesToAdd : nTabs * nSpaces
			}
			_iDecPos := _iPrevDecPos + _nSpacesToAdd
			iDecimalPositions[A_Index] := ceil(_iDecPos / nSpaces) * nSpaces
			_iPrevDecPos := iDecimalPositions[A_Index]
			_iPrevTrailDigs := maxTrailDigs[A_Index]
		}

		Loop, %_iRows%
		{
			Loop, %nInitTabs%
			{
					_inText .= "`t"
			}

			if (sCommand <> "")
			{
				_inText .= sCommand
			}

			_iRow := A_Index
			_iPrevPos := 0
			_inText .= sCommands[_iRow]

			Loop %nCols%
			{
				nIntDigs := RegExMatch(sArray[_iRow][A_Index], "\.|\Z") - 1
				_nTabs := (iDecimalPositions[A_Index] - nIntDigs) // nSpaces - _iPrevPos // nSpaces
				_iTabPos := (_iPrevPos // nSpaces + _nTabs) * nSpaces
				_nSpaces := iDecimalPositions[A_Index] - nIntDigs - (_iTabPos > _iPrevPos ? _iTabPos : _iPrevPos)
				_iTrailDigits := StrLen(RegExReplace(sArray[_iRow][A_Index], sLeadingChars))
				_iPrevPos := iDecimalPositions[A_Index] + _iTrailDigits + 1	+ 1 ; 1 for point, 1 for comma

				Loop, % _nTabs
					_inText .= "`t"
				Loop, % _nSpaces
					_inText .= " "

				if (A_Index == nCols and sArray[_iRow][A_Index] <> -1)
				{
					if (sArray[_iRow][A_Index] ~= "7\d{2}\b" > 0)
					{
						if (sStatus ~= "\d+")
						{
							sArray[_iRow][A_Index] := 700 + sStatus
						}
						else if (sStatus <> "0" and sStatus <> "")
						{
							sArray[_iRow][A_Index] := sStatus . " +  700"
						}
					}
					else if (sArray[_iRow][A_Index] ~= "9\d{2}\b" > 0)
					{
						if (sStatus ~= "\d+")
						{
							sArray[_iRow][A_Index] := 900 + sStatus
						}
						else if (sStatus <> "0" and sStatus <> "")
						{
							sArray[_iRow][A_Index] := sStatus . " +  900"
						}
					}
					else if (sArray[_iRow][A_Index] ~= "4\d{3}\b" > 0)
					{
						if (sStatus2 ~= "\d+")
						{
							sArray[_iRow][A_Index] := 4000 + sStatus2
						}
						else if (sStatus2 <> "0" and sStatus2 <> "")
						{
							sArray[_iRow][A_Index] := sStatus2 . " + 4000"
						}
					}	
					else
					{
						if (sStatus ~= "\d+")
						{
							sArray[_iRow][A_Index] := sStatus
						}
						else if (sStatus <> "0" and sStatus <> "")
						{
							sArray[_iRow][A_Index] := sStatus
						}
					}
				}
				
				_inText .= RegExReplace(sArray[_iRow][A_Index], "^\s*")

				if (A_Index < nCols)
				{
					_inText .= ","
				}
			}
			
			if (_iRow < nRows)
			{
				if (sCommand == "" and sCommands[_iRow] == "" and bAddComma == -1 or bAddComma == 1)
				{
					_inText .= ","
				}
				_inText .= "`n"
			}
		}
		
		GuiControl,, inText, %_inText%
	return
}

OnClipboardChange:
;IfWinActive, Notepad++
IfWinActive, Archicad
{
	Loop, Parse, Clipboard, `n
	{
		FoundPos := RegExMatch(A_LoopField, "(?:\s*\-?[0-9.E]+\,){2,4}")
		if FoundPos
		{
			inText .= A_LoopField . "`n"
		}
		else
		{
			break
			;FIXME
		}
	}

	if inText
	{
		TabulatorGUI()
	}
}
