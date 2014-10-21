''
'' C source code lexer, command line argument lexer
''

#include once "fbfrog.bi"

const MAXTEXTLEN = 2048

type LEXSTUFF
	i		as ubyte ptr  '' Current char, will always be <= limit
	bol		as ubyte ptr  '' Last begin-of-line

	x		as integer
	location	as TKLOCATION
	behindspace	as integer

	ckeywords	as THASH
	frogoptions	as THASH

	'' +2 extra room to allow for some "overflowing" to reduce the amount
	'' of checking needed, +1 for null terminator.
	text		as zstring * MAXTEXTLEN+2+1
end type

dim shared as LEXSTUFF lex

private sub hInitKeywords _
	( _
		byval h as THASH ptr, _
		byval first as integer, _
		byval last as integer _
	)

	hashInit( h, 12 )

	for i as integer = first to last
		var hash = hashHash( tkInfoText( i ) )
		var item = hashLookup( h, tkInfoText( i ), hash )
		hashAdd( h, item, hash, tkInfoText( i ), cast( any ptr, i ) )
	next
end sub

sub lexInit( )
	hInitKeywords( @lex.ckeywords, KW__C_FIRST, KW__C_LAST )
	hInitKeywords( @lex.frogoptions, OPT__FIRST, OPT__LAST )
end sub

private function hLookupKeyword _
	( _
		byval h as THASH ptr, _
		byval id as zstring ptr, _
		byval defaulttk as integer _
	) as integer

	var item = hashLookup( h, id, hashHash( id ) )
	if( item->s ) then
		'' Return the corresponding KW_* (C keyword) or OPT_* (command line option)
		function = cint( item->data )
	else
		function = defaulttk
	end if
end function

sub lexGetLocation( byval location as TKLOCATION ptr )
	*location = lex.location
	location->column = lex.i - lex.bol
	location->length = 1
end sub

private sub hResetColumn( )
	lex.location.column = lex.i - lex.bol
	lex.location.length = 1
end sub

private sub lexOops( byref message as string )
	dim location as TKLOCATION
	lexGetLocation( @location )
	oopsLocation( @location, message )
end sub

private sub hSetLocation( byval flags as integer = 0 )
	lex.location.length = (lex.i - lex.bol) - lex.location.column
	tkSetLocation( lex.x, @lex.location )
	if( lex.behindspace ) then
		flags or= TKFLAG_BEHINDSPACE
	end if
	tkAddFlags( lex.x, lex.x, flags )
	lex.x += 1
end sub

private sub hAddTextToken( byval tk as integer, byval begin as ubyte ptr )
	'' Insert a null terminator temporarily
	var old = lex.i[0]
	lex.i[0] = 0

	if( tk = TK_ID ) then
		'' If it's a C keyword, insert the corresponding KW_* (without
		'' storing any string data). Otherwise, if it's a random symbol,
		'' just insert a TK_ID and store the string data on it.
		tk = hLookupKeyword( @lex.ckeywords, begin, TK_ID )
		if( tk <> TK_ID ) then
			begin = NULL
		end if
	end if

	tkInsert( lex.x, tk, begin )
	hSetLocation( )

	lex.i[0] = old
end sub

private sub hReadBytes( byval tk as integer, byval length as integer )
	lex.i += length
	tkInsert( lex.x, tk )
	hSetLocation( )
end sub

private sub hNewLine( )
	lex.bol = lex.i
	lex.location.linenum += 1
	lex.location.source->lines = lex.location.linenum + 1
end sub

'' // C++ comment
'' The EOL behind the comment is not skipped; it's a (separate) token.
'' The comment may contain escaped newlines ('\' [Spaces] EOL)
'' which means the comment continues on the next line.
private sub hSkipLineComment( )
	lex.i += 2
	var escaped = FALSE

	do
		select case( lex.i[0] )
		case 0
			exit do

		case CH_CR
			if( escaped = FALSE ) then
				exit do
			end if

			if( lex.i[1] = CH_LF ) then	'' CRLF
				lex.i += 1
			end if
			lex.i += 1
			hNewLine( )

		case CH_LF
			if( escaped = FALSE ) then
				exit do
			end if
			lex.i += 1
			hNewLine( )

		case CH_SPACE, CH_TAB
			'' Spaces don't change escaped status
			'' (at least gcc/clang support spaces between \ and EOL)
			lex.i += 1

		case CH_BACKSLASH
			escaped = TRUE
			lex.i += 1

		case else
			escaped = FALSE
			lex.i += 1
		end select
	loop
end sub

'' /* C comment */
private sub hSkipComment( )
	'' /*
	lex.i += 2

	do
		select case( lex.i[0] )
		case 0
			lexOops( "comment left open" )

		case CH_STAR		'' *
			if( lex.i[1] = CH_SLASH ) then	'' */
				exit do
			end if
			lex.i += 1

		case CH_CR
			if( lex.i[1] = CH_LF ) then	'' CRLF
				lex.i += 1
			end if
			lex.i += 1
			hNewLine( )

		case CH_LF
			lex.i += 1
			hNewLine( )

		case else
			lex.i += 1
		end select
	loop

	'' */
	lex.i += 2
end sub

'' Identifier/keyword lexing: sequences of A-Za-z0-9_
'' Starting out at A-Za-z_
'' Resulting in a TK_ID or KW_* if it's a keyword.
private sub hReadId( )
	var begin = lex.i

	do
		lex.i += 1

		select case as const( lex.i[0] )
		case CH_A   to CH_Z  , _
		     CH_L_A to CH_L_Z, _
		     CH_0   to CH_9  , _
		     CH_UNDERSCORE

		case else
			exit do
		end select
	loop

	hAddTextToken( TK_ID, begin )
end sub

'' Number literal lexing: sequences of A-Za-z0-9_. and +- if preceded by eE.
'' Here in the lexer we don't validate the syntax. Tokens such as '08' or
'' '123foobar' are allowed here even though they're invalid number literals,
'' because they can be used with the ## operator. The syntax checks are done
'' later in hNumberLiteral() when the parsers encounter a TK_NUMBER.
private sub hReadNumber( )
	var begin = lex.i

	do
		lex.i += 1

		select case as const( lex.i[0] )
		case CH_A to CH_Z, CH_L_A to CH_L_Z, CH_0 to CH_9, CH_UNDERSCORE, CH_DOT

		'' +|- is only allowed if preceded by e|E (in other cases, +|-
		'' starts a new token separate from the number literal)
		case CH_PLUS, CH_MINUS
			assert( begin < lex.i )
			select case( lex.i[-1] )
			case CH_E, CH_L_E
			case else
				exit do
			end select

		case else
			exit do
		end select
	loop

	hAddTextToken( TK_NUMBER, begin )
end sub

private function hReadEscapeSequence( ) as ulongint
	select case( lex.i[0] )
	case CH_DQUOTE    : lex.i += 1 : function = CH_DQUOTE     '' \"
	case CH_QUOTE     : lex.i += 1 : function = CH_QUOTE      '' \'
	case CH_QUEST     : lex.i += 1 : function = CH_QUEST      '' \?
	case CH_BACKSLASH : lex.i += 1 : function = CH_BACKSLASH  '' \\
	case CH_L_A       : lex.i += 1 : function = CH_BELL       '' \a
	case CH_L_B       : lex.i += 1 : function = CH_BACKSPACE  '' \b
	case CH_L_F       : lex.i += 1 : function = CH_FORMFEED   '' \f
	case CH_L_N       : lex.i += 1 : function = CH_LF         '' \n
	case CH_L_R       : lex.i += 1 : function = CH_CR         '' \r
	case CH_L_T       : lex.i += 1 : function = CH_TAB        '' \t
	case CH_L_V       : lex.i += 1 : function = CH_VTAB       '' \v

	'' \NNN (octal, max 3 digits)
	case CH_0 to CH_7
		dim as uinteger value
		var length = 0
		do
			value = (value shl 3) + (lex.i[0] - asc( "0" ))
			length += 1
			lex.i += 1
		loop while( (lex.i[0] >= CH_0) and (lex.i[0] <= CH_7) and _
		            (length < 3) )

		function = value

	'' \xNNNN... (hexadecimal, as many digits as possible)
	case CH_L_X
		dim as ulongint value
		var length = 0
		lex.i += 1
		do
			dim as uinteger digit = lex.i[0]

			select case( digit )
			case CH_0 to CH_9
				digit -= CH_0
			case CH_A to CH_F
				digit -= (CH_A - 10)
			case CH_L_A to CH_L_F
				digit -= (CH_L_A - 10)
			case else
				exit do
			end select

			value = (value shl 4) + digit

			length += 1
			lex.i += 1
		loop

		function = value

	case else
		lexOops( "unknown escape sequence" )
	end select
end function

private sub hReadString( )
	'' String/char literal parsing, starting at ", ', or L, covering:
	''    'a'
	''    L'a'
	''    "foo"
	''    L"foo"
	'' The string content is stored into the token, but not the quotes.
	'' Escape sequences are expanded except for \\ and \0.
	'' String literals may contain escaped EOLs and continue on the next
	'' line.

	var id = TK_STRING
	var is_wchar = FALSE

	if( lex.i[0] = CH_L ) then
		lex.i += 1
		id = TK_WSTRING
	end if

	var quotechar = lex.i[0]
	select case( quotechar )
	case CH_QUOTE
		id = iif( (id = TK_WSTRING), TK_WCHAR, TK_CHAR )
	case CH_LT
		quotechar = CH_GT
	end select

	lex.i += 1
	var j = 0  '' current write position in text buffer
	do
		select case( lex.i[0] )
		case quotechar
			exit do

		case CH_LF, CH_CR, 0
			lexOops( "string/char literal left open" )

		case CH_BACKSLASH	'' \
			lex.i += 1

			'' Look-ahead and check whether it's an escaped EOL.
			'' Escaped EOLs are not included in the string literal.
			var i = 0
			while( (lex.i[i] = CH_TAB) or (lex.i[i] = CH_SPACE) )
				i += 1
			wend

			var found_eol = FALSE
			select case( lex.i[i] )
			case CH_CR
				i += 1
				if( lex.i[i] = CH_LF ) then	'' CRLF
					i += 1
				end if
				found_eol = TRUE
			case CH_LF
				i += 1
				found_eol = TRUE
			end select

			if( found_eol ) then
				lex.i += i
				hNewLine( )
			else
				var value = hReadEscapeSequence( )

				select case( value )
				case is > &hFFu
					lexOops( "escape sequence value bigger than " & &hFFu & " (&hFF): " & value & " (&h" & hex( value ) & " )" )

				'' Encode embedded nulls as "\0", and then also backslashes
				'' as "\\" to prevent ambiguity with the backslash in "\0".
				'' This allows the string literal content to still be
				'' represented as null-terminated string.
				case 0
					lex.text[j] = CH_BACKSLASH : j += 1
					lex.text[j] = CH_0         : j += 1
				case CH_BACKSLASH
					lex.text[j] = CH_BACKSLASH : j += 1
					lex.text[j] = CH_BACKSLASH : j += 1

				case else
					lex.text[j] = value : j += 1
				end select
			end if

		case else
			lex.text[j] = lex.i[0] : j += 1
			lex.i += 1
		end select

		if( j > MAXTEXTLEN ) then
			lexOops( "string literal too long, MAXTEXTLEN=" & MAXTEXTLEN )
		end if
	loop

	'' closing quote
	lex.i += 1

	'' null-terminator
	lex.text[j] = 0

	tkInsert( lex.x, id, lex.text )
	hSetLocation( )
end sub

private sub lexNext( )
	'' Skip spaces
	lex.behindspace = FALSE
	while( (lex.i[0] = CH_TAB) or (lex.i[0] = CH_SPACE) )
		lex.i += 1
		lex.behindspace = TRUE
	wend

	hResetColumn( )

	'' Identify the next token
	select case as const( lex.i[0] )
	case CH_CR
		if( lex.i[1] = CH_LF ) then	'' CRLF
			lex.i += 1
		end if
		hReadBytes( TK_EOL, 1 )
		hNewLine( )

	case CH_LF
		hReadBytes( TK_EOL, 1 )
		hNewLine( )

	case CH_FORMFEED
		lex.i += 1

	case CH_EXCL		'' !
		if( lex.i[1] = CH_EQ ) then	'' !=
			hReadBytes( TK_EXCLEQ, 2 )
		else
			hReadBytes( TK_EXCL, 1 )
		end if

	case CH_DQUOTE		'' "
		hReadString( )

	case CH_HASH		'' #
		if( lex.i[1] = CH_HASH ) then	'' ##
			hReadBytes( TK_HASHHASH, 2 )
		else
			hReadBytes( TK_HASH, 1 )
		end if

	case CH_PERCENT		'' %
		if( lex.i[1] = CH_EQ ) then	'' %=
			hReadBytes( TK_PERCENTEQ, 2 )
		else
			hReadBytes( TK_PERCENT, 1 )
		end if

	case CH_AMP		'' &
		select case( lex.i[1] )
		case CH_AMP	'' &&
			hReadBytes( TK_AMPAMP, 2 )
		case CH_EQ	'' &=
			hReadBytes( TK_AMPEQ, 2 )
		case else
			hReadBytes( TK_AMP, 1 )
		end select

	case CH_QUOTE		'' '
		hReadString( )

	case CH_LPAREN		'' (
		hReadBytes( TK_LPAREN, 1 )

	case CH_RPAREN		'' )
		hReadBytes( TK_RPAREN, 1 )

	case CH_STAR		'' *
		if( lex.i[1] = CH_EQ ) then	'' *=
			hReadBytes( TK_STAREQ, 2 )
		else
			hReadBytes( TK_STAR, 1 )
		end if

	case CH_PLUS		'' +
		select case( lex.i[1] )
		case CH_PLUS	'' ++
			hReadBytes( TK_PLUSPLUS, 2 )
		case CH_EQ	'' +=
			hReadBytes( TK_PLUSEQ, 2 )
		case else
			hReadBytes( TK_PLUS, 1 )
		end select

	case CH_COMMA		'' ,
		hReadBytes( TK_COMMA, 1 )

	case CH_MINUS		'' -
		select case( lex.i[1] )
		case CH_GT	'' ->
			hReadBytes( TK_ARROW, 2 )
		case CH_MINUS	'' --
			hReadBytes( TK_MINUSMINUS, 2 )
		case CH_EQ	'' -=
			hReadBytes( TK_MINUSEQ, 2 )
		case else
			hReadBytes( TK_MINUS, 1 )
		end select

	case CH_DOT		'' .
		select case( lex.i[1] )
		case CH_0 to CH_9   '' 0-9 (Decimal float beginning with '.')
			hReadNumber( )
		case CH_DOT
			if( lex.i[2] = CH_DOT ) then	'' ...
				hReadBytes( TK_ELLIPSIS, 3 )
			else
				hReadBytes( TK_DOT, 1 )
			end if
		case else
			hReadBytes( TK_DOT, 1 )
		end select

	case CH_SLASH		'' /
		select case( lex.i[1] )
		case CH_EQ	'' /=
			hReadBytes( TK_SLASHEQ, 2 )
		case CH_SLASH	'' //
			hSkipLineComment( )
		case CH_STAR	'' /*
			hSkipComment( )
		case else
			hReadBytes( TK_SLASH, 1 )
		end select

	case CH_0 to CH_9	'' 0 - 9
		hReadNumber( )

	case CH_COLON		'' :
		hReadBytes( TK_COLON, 1 )

	case CH_SEMI		'' ;
		hReadBytes( TK_SEMI, 1 )

	case CH_LT		'' <
		select case( lex.i[1] )
		case CH_LT	'' <<
			if( lex.i[2] = CH_EQ ) then	'' <<=
				hReadBytes( TK_LTLTEQ, 3 )
			else
				hReadBytes( TK_LTLT, 2 )
			end if
		case CH_EQ	'' <=
			hReadBytes( TK_LTEQ, 2 )
		case CH_GT	'' <>
			hReadBytes( TK_LTGT, 2 )
		case else
			'' If it's an #include, parse <...> as string literal
			if( tkGet( lex.x - 1 ) = KW_INCLUDE ) then
				if( tkGet( lex.x - 2 ) = TK_HASH ) then
					select case( tkGet( lex.x - 3 ) )
					case TK_EOL, TK_EOF
						hReadString( )
						exit select, select
					end select
				end if
			end if

			hReadBytes( TK_LT, 1 )
		end select

	case CH_EQ		'' =
		if( lex.i[1] = CH_EQ ) then	'' ==
			hReadBytes( TK_EQEQ, 2 )
		else
			hReadBytes( TK_EQ, 1 )
		end if

	case CH_GT		'' >
		select case( lex.i[1] )
		case CH_GT	'' >>
			if( lex.i[2] = CH_EQ ) then	'' >>=
				hReadBytes( TK_GTGTEQ, 3 )
			else
				hReadBytes( TK_GTGT, 2 )
			end if
		case CH_EQ	'' >=
			hReadBytes( TK_GTEQ, 2 )
		case else
			hReadBytes( TK_GT, 1 )
		end select

	case CH_QUEST	'' ?
		hReadBytes( TK_QUEST, 1 )

	case CH_A       to (CH_L - 1), _	'' A-Z except L
	     (CH_L + 1) to CH_Z
		hReadId( )

	case CH_L		'' L
		select case( lex.i[1] )
		case CH_QUOTE, CH_DQUOTE	'' ', "
			hReadString( )
		case else
			hReadId( )
		end select

	case CH_LBRACKET	'' [
		hReadBytes( TK_LBRACKET, 1 )

	case CH_BACKSLASH	'' \
		'' Check for escaped EOLs and solve them out
		'' '\' [Space] EOL

		var i = 1
		while( (lex.i[i] = CH_TAB) or (lex.i[i] = CH_SPACE) )
			i += 1
		wend

		var found_eol = FALSE
		select case( lex.i[i] )
		case CH_CR
			i += 1
			if( lex.i[i] = CH_LF ) then	'' CRLF
				i += 1
			end if
			found_eol = TRUE
		case CH_LF
			i += 1
			found_eol = TRUE
		end select

		if( found_eol ) then
			lex.i += i
			hNewLine( )
		else
			hReadBytes( TK_BACKSLASH, 1 )
		end if

	case CH_RBRACKET	'' ]
		hReadBytes( TK_RBRACKET, 1 )

	case CH_CIRC		'' ^
		if( lex.i[1] = CH_EQ ) then	'' ^=
			hReadBytes( TK_CIRCEQ, 2 )
		else
			hReadBytes( TK_CIRC, 1 )
		end if

	case CH_L_A to CH_L_Z, _	'' a-z
	     CH_UNDERSCORE		'' _
		hReadId( )

	case CH_LBRACE		'' {
		hReadBytes( TK_LBRACE, 1 )

	case CH_PIPE		'' |
		select case( lex.i[1] )
		case CH_PIPE	'' ||
			hReadBytes( TK_PIPEPIPE, 2 )
		case CH_EQ	'' |=
			hReadBytes( TK_PIPEEQ, 2 )
		case else
			hReadBytes( TK_PIPE, 1 )
		end select

	case CH_RBRACE		'' }
		hReadBytes( TK_RBRACE, 1 )

	case CH_TILDE		'' ~
		hReadBytes( TK_TILDE, 1 )

	case else
		lexOops( "stray &h" + hex( lex.i[0], 2 ) + " byte" )

	end select
end sub

''
'' C lexer entry point
''
function lexLoadC( byval x as integer, byval source as SOURCEBUFFER ptr ) as integer
	lex.x = x
	lex.location.source = source
	lex.location.linenum = 0
	lex.location.source->lines = 1
	lex.i = source->buffer
	lex.bol = lex.i

	'' Tokenize and insert into tk buffer
	while( lex.i[0] )
		lexNext( )
	wend

	function = lex.x
end function

private sub hReadArg( byval tk as integer )
	var j = 0
	var begin = lex.i

	do
		select case( lex.i[0] )
		case 0, CH_TAB, CH_SPACE, CH_VTAB, CH_FORMFEED, CH_CR, CH_LF
			exit do

		case CH_DQUOTE, CH_QUOTE
			var quotechar = lex.i[0]

			'' String, skip until closing dquote or EOL/EOF
			do
				lex.i += 1

				select case( lex.i[0] )
				case quotechar
					exit do

				'' Handle \\ and \" if inside "..." string
				'' (so no escape sequences inside '...')
				case CH_BACKSLASH
					if( quotechar = CH_DQUOTE ) then
						select case( lex.i[1] )
						case CH_BACKSLASH
							lex.text[j] = lex.i[0] : j += 1
							lex.i += 1
						case quotechar
							lex.i += 1
							lex.text[j] = lex.i[0] : j += 1
						case else
							lex.text[j] = lex.i[0] : j += 1
						end select
					else
						lex.text[j] = lex.i[0] : j += 1
					end if

				case 0, CH_CR, CH_LF
					lexOops( "string literal left open" )

				case else
					lex.text[j] = lex.i[0] : j += 1

				end select

				if( j > MAXTEXTLEN ) then
					lexOops( "argument too long, MAXTEXTLEN=" & MAXTEXTLEN )
				end if
			loop

		case else
			lex.text[j] = lex.i[0] : j += 1
		end select

		if( j > MAXTEXTLEN ) then
			lexOops( "argument too long, MAXTEXTLEN=" & MAXTEXTLEN )
		end if

		lex.i += 1
	loop

	'' null terminator
	lex.text[j] = 0
	var text = @lex.text

	select case( tk )
	case TK_MINUS
		tk = hLookupKeyword( @lex.frogoptions, text, TK_STRING )
		if( tk = TK_STRING ) then
			lex.location.column = begin - lex.bol
			lex.location.length = lex.i - begin
			oopsLocation( @lex.location, "unknown command line option '" + *text + "'" )
		end if
		text = NULL
	case TK_STRING
		if( strIsValidSymbolId( text ) ) then
			tk = TK_ID
		end if
	end select

	tkInsert( lex.x, tk, text )
	hSetLocation( )
end sub

''
'' "Command line" argument lexer, used for turning fbfrog's command line into
'' tokens, and also for turning @files into tokens.
''
'' Syntax rules:
''   * white-space chars separate arguments
''   * any non-white-space sequence is an argument
''   * "..." or '...' can be used in arguments to include whitespace
''   * "..." allows \" and \\ escape sequences
''
function lexLoadArgs( byval x as integer, byval source as SOURCEBUFFER ptr ) as integer
	lex.x = x
	lex.location.source = source
	lex.location.linenum = 0
	lex.location.source->lines = 1
	lex.i = source->buffer
	lex.bol = lex.i
	lex.behindspace = TRUE

	do
		hResetColumn( )

		select case( lex.i[0] )
		case 0
			exit do

		case CH_TAB, CH_SPACE, CH_VTAB, CH_FORMFEED
			lex.i += 1

		case CH_CR
			lex.i += 1
			if( lex.i[0] = CH_LF ) then
				lex.i += 1
			end if
			hNewLine( )

		case CH_LF
			lex.i += 1
			hNewLine( )

		'' -option
		case CH_MINUS
			hReadArg( TK_MINUS )

		'' @filename
		case CH_AT
			lex.i += 1
			hReadArg( TK_ARGSFILE )

		case else
			'' Non-whitespace: argument starts here, until whitespace/EOF
			hReadArg( TK_STRING )

		end select
	loop

	function = lex.x
end function

'' Retrieve a line of source code from the original input data for display in
'' error messages.
function lexPeekLine _
	( _
		byval source as SOURCEBUFFER ptr, _
		byval targetlinenum as integer _
	) as string

	'' Find the targetlinenum'th line of code, bol will end up pointing
	'' to the begin of line of the target line, i will point to the end of
	'' the target line.
	dim as ubyte ptr i = source->buffer
	var bol = i
	var linenum = 0
	do
		select case( i[0] )
		case 0, CH_LF, CH_CR  '' EOF or EOL
			if( linenum = targetlinenum ) then
				exit do
			end if

			select case( i[0] )
			case CH_CR
				if( i[1] = CH_LF ) then '' CRLF
					i += 1
				end if
			case 0
				exit do
			end select

			i += 1
			linenum += 1
			bol = i

		case else
			i += 1
		end select
	loop

	'' Turn the target line of code into a pretty string
	dim s as string
	while( bol < i )
		dim as integer ch = bol[0]

		'' Replace nulls, tabs, and other control chars with spaces
		select case( ch )
		case is < CH_SPACE, CH_DEL
			ch = CH_SPACE
		end select

		s += chr( ch )

		bol += 1
	wend

	function = s
end function
