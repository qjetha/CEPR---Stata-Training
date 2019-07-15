/*************************************************************
Title: "Stata 104: Efficient Coding in Stata!"
Author: Qayam Jetha
Date: Jan 16, 2019

Contents: (1) System Parameters
		  (2) String Functions
		  (3) Regular Expressions
		  (4) Extended Macro Functions
		  (5) Dates (Short)
*************************************************************/

clear all
set more off

/*  (1) System Parameters: Can access certain system files/parameters using 
	Stata’s creturn. Like returned results (“return list”), but for the Stata 
	system in general and not for the results of a specific command.
*/

creturn list

/*  Eee gads! Lots of stuff. Most not at all helpful. Potentially useful clist
	values include: c(username), c(os), c(current_date), c(pi), c(Mons)
*/

local user = "`c(username)'"

if "`c(os)'" == "MacOSX" {
	global data = "/Users/`user'/Desktop/"
}

else {
	global data = "C:\Users\\`user'\Desktop\"
}


use "${data}mock_dataset", clear

*log using "${data}Stata104_`c(username)'_`c(current_date)'.smcl" 




************
************

///  (2) String Functions

	di trim("    CEPR    is cool ")		// trim removes leading or trailing spaces
	di itrim("CEPR   is Awesome!")		// itrim collapses consecutive internal spaces to 1 space 

	di upper("CEPR is awesome!")		// upper, proper, lower


* Let's look at the string variable child_caste - what's the problem with this variable?
ta child_caste

di "child_caste has {it}`r(r)' {sf}unique values prior to cleaning"


* Don’t let case or space mess you up!
replace child_caste = trim(itrim(upper(child_caste)))

qui ta child_caste
di "child_caste has {it}`r(r)' {sf}unique values after the first string cleaning"


* Check the list of characters and make sure nothing is weird!
capture ssc install charlist

charlist child_caste

* Looks like we got some weird characters we need to replace!

	di(strpos("Pierre Pressure", "r"))		// The position of "r" in "Pierre Pressure"
	di(strrpos("Pierre Pressure", "r"))		// Same as strpos, but finds the position of the last "r"

	di(subinstr("Pierre Pressure", "Pierre", "Peer", 1))	// Substitute the 1st occurrence of the word "Pierre" with "Peer" in "Pierre Pressure"
	

ta child_caste if strpos(child_caste, ".") != 0
replace child_caste = subinstr(child_caste, ".", " ", .)

* We good now? No! Why?
replace child_caste = itrim(child_caste)

/*  Removing these non-alphabetical characters should help with the string matching
	but notice there are still instances where the caste name is duplicate but spelled
	marginally different (e.g. VAISHANAV, VAISHANV, VAISHNAV). This would be awful to 
	try to match these variant spellings manually.
	
	Two commands can help to automate this string matching exercise (probabilistic data matching):
	strgroup, & reclink.
*/


* String Parsing - Sometimes we just want part of a string
	
	di(substr("Econometrics", 2, 3))		// substr(string, n1, n2) extracts the part of string that starts at n1 and goes n2 characters
	di(substr("Econometrics", strpos("Econometrics", "c"), strlen("con")))

gen gender = substr(child_gender, 1, 1)
list child_gender gender in 1/7, clean


* String Parsing - Other times we want to split a string variable by a parse character
split(enum), parse("_") gen(enum_name)

list enum* in 1/5, clean

/* Recap: See "help string functions" for more info. Remember, we covered:
	-trim
	-itrim
	-upper
	-lower
	-proper
	-charlist
	-strpos
	-subinstr
	-substr
	-strlen
	-split*
	
	*Not technically a string function. Split is a command...
*/




************
************

/*  (3) Regular Expressions - Regular expressions are a sequence of characters that 
	can be used to find patterns within strings (string searching). Regular expressions 
	have a long history in computer science and are found in most programming languages. 
	What follows are a few basic operations (read Stata Help for a more comprehensive intro)
*/

* Want to tabulate values of child_caste that contain a "_". This is a simple regular expression
* & is an alternative to the strpos string function used earlier.

ta child_caste if regexm(child_caste, "_")	== 1		    // returns a dummy variable equal to one if the regular expression is satisifed by the string
replace child_caste = regexr(child_caste, "_", "")		 	// replaces the regular expression in child_caste to a string value = ""


* Recall these as defined above are similar in function to the string functions strpos and subinstr, 
* but regular expressions can get much more flexible


* Want to create a dummy variable "conform" if a child_caste starts with an "M" or an "S" and ends with an "L"
gen conform = regexm(child_caste, "^[MS][A-Z]*[L]$")

/* ^ -> match at the beginning of the string. Wildcard character. Doesn't match a character only specifies location of match.
   [MS] -> denotes a set of allowable characters to be used in matching. In this case I want to match M and S.
   [A-Z] -> denotes a set of allowable characters to be used in matching. In this case I want to match all uppercase Alphabetical characters.
   * -> match zero or more of the proceeding expression. Zero or more of letters inbetween M and L.
   $ -. match the preceding expression at the end of the string. 
*/

* (+) is another wildcard character that matches one or more of the previous expression. 
gen conform1 = regexm(child_caste, "^[MS][A-Z]+[L]$")

capture assert conform==conform1				// suppress output & the error break (return code)

if _rc!=0 {										// if there is an error the return code will not equal zero.
	list child_caste if conform!=conform1
}



* What if we want to match on a character that is a wildcard character
ta child_caste if regexm(child_caste, "*")==1		// this is problematic.
ta child_caste if regexm(child_caste, "\*")==1		// "\" is the escape char - used to match chars that would be interpreted as a regular-expression.



* regexs - pulling subexpressions from a regular expression match. Let's check whether our start date in string format
* follows the specified convention
ta string_start_date
des string_start_date		// should be specified in day/month/year

*Let's check to make sure that the month part of the string is less than 13 
gen month_check = regexs(1) if regexm(string_start_date, "^[0-9]+/([0-9]+)/[0-9]+$")

* The parentheses denotes a sub-expression group. Regexs pulls out the specified subexpression. In this case the month.
ta month_check

replace string_start_date = regexs(2)+regexs(1)+regexs(3) if regexm(string_start_date, "^([0-9]+/)([0-9]+/)([0-9]+)$")==1 & real(month_check) > 12


/* Recap: regexm, regexr, and regexs are the regular expression functions you will use. 
		  When defining your regular expressions, remember these operators:
		  ^ match expression at beginning of string	(e.g. "^A")
		  [] denotes a set of allowable characters to be used in matching	(e.g. "[a-zA-Z0-9]
		  * Match zero or more of prior expression
		  + Match one or more of prior expression
		  $ Match expression at the end of the string
		  \ escape character to match a regular expression operator as a literal
		  () denotes a sub-expression group
*/




************
************

/*  (4) Extended Macro Functions - Take the form "local macroname : ..."
	they are useful extensions of local macros that can make your code 
	more efficient! 
*/

qui sum age
di `r(mean)'								// Recall, `r(mean)' pulls the mean from the previous summarize command. To see returned results, type "return list" after sum.
local mean_age : di %4.2f `r(mean)'			// This extended macro function (di) to format results is useful, especially when outputing results
di `mean_age'


* word count and word #
ta school_transport							// This doesn't look right! We need to replace the months with the numeric equivalent to represent the right response value

local months = c(Mons)
local len_months : word count `months'		// Sidrah showed us this yesterday as well!

forval month_num = 1 / `len_months' {		// Note, there is a shorthand for extended functions. Can remove line 226 & instead of calling the local len_months, can write `: word count `months''.
	
	local month_str : word `month_num' of `months'			// picks the month_num word from the local months
	replace school_transport = regexr(school_transport, "`month_str'", "`month_num'")

}


* variable label and value label are useful especially when graphing!
local vlab_age : variable label school_transport
di "`vlab_age'" 


local vlab_name : value label hindi_level		// pulls the name of the value label that the variable hindi_level contains
local xlabel = ""								// specify an empty local container which I will put the categorical value and then the value label corresponding to that value

qui ta hindi_level
local end_loop = `r(r)'							// pulls the total number of value labels in the variable hindi_level

forval label = 1 / `end_loop' {
	
	local lab_name : label `vlab_name' `label'			// gets the value label for the first value, second value, etc.
	local xlabel `"`xlabel' `label' "`lab_name'""'		// adds the categorical value and the corresponding value label to the xlabel macro
}

macro list

di "`xlabel'" 							// oh dear, what is the problem?
di `"`xlabel'"'							// Now I can use this macro to specify my x-axis labels in my graph!



* dir extended macro + macro lists.
local dir : dir "${data}" files "*"
local dir_dta : dir "${data}" files "*.dta"

local dir : list dir - dir_dta 		// a local list expression (see help macro list)

assert strpos("`dir'", "mock_dataset.dta") == 0

help macro list



/*  Recap: Extended Macro Functions and macro list functions extend the usefulness
	of locals and help make code more efficient. 
	
	See "help extended macro functions" & "help macro list" for more of these functions.
	Another one that may be useful is the subinstr extended function though I did not
	go over it here.
	
	We went over:
		local name : di %4.2f number				to round
		local name : word count string				number of words
		local name : word # of string				pulls the X# word in the string
		local name : variable label variable		pulls the name of the value label that is defined to a variable
		local name : label value_label_name value	pulls the value label code that is mapped to a specific value
		local name : dir path files name			pulls the files that contain a specific name within a given directory path
		local name : list local1 - local2 			returns a list containing elements of local1 with the elements of local2 removed
*/




************
************

/* Dates - A Very (Very) Short Primer */

* Converting string date to Stata date format

gen date_formatted = date(string_start_date, "DMY")		// stata calculates dates as the number of days that has elapsed since 01jan1960)
ta date_formatted

format date_formatted %td

gen day = day(date_formatted)
gen month = month(date_formatted)
gen year = year(date_formatted)

list string_start_date date_formatted day month year in 1/10, clean

* Things get marginally more complicated when you have a string with date time
* In this case to convert a string with date and time to stata format we use the 
* clock function. Check out 'help datetime' for more info. 


capture log close

exit
