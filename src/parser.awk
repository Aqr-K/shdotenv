function syntax_error(msg) {
  sub("[\n]+$", "", CURRENT_LINE)
  abort(sprintf("`%s': %s", CURRENT_LINE, msg))
}

function trim(str) {
  gsub("(^[ \t]+)|([ \t]+$)", "", str)
  return str
}

function rtrim(str) {
  sub("[ \t]+$", "", str)
  return str
}

function chomp(str) {
  sub("\n$", "", str)
  return str
}

function dialect(name) {
  return index("|" name "|", "|" DIALECT "|") > 0
}

function unescape(str, escape, keep_backslash,  escapes, idx) {
  split(escape, escapes, "")
  for (idx in escapes) {
    escape = escapes[idx]
    if (str == "\\" escape) return ESCAPE[escape]
  }
  return (keep_backslash ? str : substr(str, 2))
}

function unquote(str, quote) {
  if (match(str, "^" quote ".*" quote "$")) {
    gsub("^['\"]|['\"]$", "", str)
    return str
  }
  syntax_error("unterminated quoted string")
}

function expand_value(str, quote,  variable, new_val, esc_chars_for_dialect, pos, len) {
  ESCAPED_CHARACTER = "\\\\."
  META_CHARACTER_DQ = "[$`\"\\\\]"
  VARIABLE_EXPANSION = "\\$[{][^}]*}"

  if (dialect("ruby|node|go|rust")) {
    VARIABLE_EXPANSION = "\\$" IDENTIFIER "|" VARIABLE_EXPANSION
  }

  match_pattern = ESCAPED_CHARACTER "|" VARIABLE_EXPANSION
  if (quote == DOUBLE_QUOTES) {
    match_pattern = match_pattern "|" META_CHARACTER_DQ
  } else if (quote == NO_QUOTES) {
    match_pattern = match_pattern "|\\$"
  }

  while(match(str, match_pattern)) {
    pos = RSTART
    len = RLENGTH
    variable = substr(str, pos, len)

    if (match(variable, "^" ESCAPED_CHARACTER "$")) {
      if (quote == DOUBLE_QUOTES) {
        if (dialect("posix")) { 
          esc_chars_for_dialect = "$`\"\\\n"; variable = unescape(variable, esc_chars_for_dialect, KEEP) 
        } else if (dialect("ruby|go")) { 
          esc_chars_for_dialect = "nr"; variable = unescape(variable, esc_chars_for_dialect, NO_KEEP)
        } else if (dialect("node")) { 
          esc_chars_for_dialect = "n"; variable = unescape(variable, esc_chars_for_dialect, KEEP)
        } else if (dialect("python")) { 
          esc_chars_for_dialect = "abfnrtv"; variable = unescape(variable, esc_chars_for_dialect, KEEP) 
        } else if (dialect("php")) { 
          esc_chars_for_dialect = "fnrtv"; temp_char = substr(variable,2,1)
          if (index(esc_chars_for_dialect, temp_char) || temp_char == "\\") {
            variable = unescape(variable, esc_chars_for_dialect, KEEP)
          } else {
            syntax_error("invalid escape sequence for php double-quoted string: " variable)
          }
        } else if (dialect("rust")) { 
          esc_chars_for_dialect = "n"; temp_char = substr(variable,2,1)
          if (index(esc_chars_for_dialect, temp_char) || temp_char == "\\") {
            variable = unescape(variable, esc_chars_for_dialect, KEEP)
          } else {
            syntax_error("invalid escape sequence for rust double-quoted string: " variable)
          }
        } else { 
          variable = substr(variable, 2) 
        }
      } else if (quote == NO_QUOTES) {
        if (dialect("python")) {
          esc_chars_for_dialect = "abfnrtv'\"\\"
          variable = unescape(variable, esc_chars_for_dialect, KEEP)
        } else {
          esc_chars_for_dialect = "'\"\\"
          variable = unescape(variable, esc_chars_for_dialect, KEEP)
        }
      }
    } else if (quote == DOUBLE_QUOTES && match(variable, "^" META_CHARACTER_DQ "$")) {
      if (variable == "$" && dialect("posix|python|php")) {
      } else if (variable == "$" && !dialect("posix|python|php")) {
      } else if (variable == "\"" || variable == "`") {
        if (dialect("python") && variable == "`") {
        } else {
            syntax_error("the metacharacter '" variable "' must be escaped in double quotes for this dialect")
        }
      }
    }

    if (match(variable, "^\\$" IDENTIFIER "$")) {
      variable = expand_env(substr(variable, 2))
    } else if (match(variable, "^\\$[{]" IDENTIFIER "}$")) {
      variable = expand_env(substr(variable, 3, length(variable) - 3))
    } else if (match(variable, "^" VARIABLE_EXPANSION "$")) {
      if (substr(variable,1,2) == "${" && !match(variable, "^\\$[{]" IDENTIFIER "}$")) {
         syntax_error("the variable name is not a valid identifier in ${...}")
      } else if (substr(variable,1,1) == "$" && substr(variable,1,2) != "${" && !match(variable, "^\\$" IDENTIFIER "$") ) {
         if (dialect("ruby|node|go|rust")) {
            syntax_error("the variable name is not a valid identifier after $")
         }
      }
    }

    new_val = new_val substr(str, 1, pos - 1) variable
    str = substr(str, pos + len)
  }
  return new_val str
}

function se_key(key) {
  if (dialect("ruby|node|python|php|go")) {
    key = trim(key)
  }
  if (match(key, "(^[ \t]+|[ \t]+$)")) {
    abort(sprintf("`%s': no space allowed after the key", key))
  }
  if (!match(key, "^(export[ \t]+)?" IDENTIFIER "$")) {
    abort(sprintf("`%s': the key is not a valid identifier", key))
  }
  return key
}

function se_key_only(str) {
  if (!sub("^export[ \t]+", "", str)) {
    syntax_error("not a variable definition")
  }
  sub("[ \t]#.*", "", str)
  if (!match(str, "^(" IDENTIFIER "[ \t]*)+$")) {
    abort(sprintf("`%s': the key is not a valid identifier", str))
  }
  return str
}

function se_raw_value(str) {
  return str
}

function parse_unquoted_value(str) {
  if (dialect("posix")) {
    if (match(str, "[ \t]")) {
      syntax_error("spaces are not allowed without quoting")
    }

    if (match(str, "[][{}()<>\"'`!$&~|;\\\\*?]")) {
      syntax_error("using without quotes is not allowed: !$&()*;<>?[\\]`{|}~")
    }

    if (match(str, /^=.*/)) {
      syntax_error("unquoted '=' not allowed for first character")
    }
  } else {
    str = trim(str)
  }

  return expand_value(str, NO_QUOTES)
}

function parse_single_quoted_value(str) {
  if (dialect("python")) {
    new_s = ""
    i = 1
    while (i <= length(str)) {
      char = substr(str, i, 1)
      if (char == "\\") {
        if (i + 1 <= length(str)) {
          next_char = substr(str, i + 1, 1)
          if (next_char == "'" || next_char == "\\") {
            new_s = new_s next_char
            i++
          } else {
            new_s = new_s char next_char
            i++
          }
        } else {
          new_s = new_s char
        }
      } else if (char == "'") {
        syntax_error("unescaped single quote found in Python single-quoted value")
      } else {
        new_s = new_s char
      }
      i++
    }
    return new_s
  } else if (dialect("ruby|php|node|go")) {
    return str
  } else {
    if (index(str, "'")) {
      syntax_error("single quotes cannot be used in the value of a single-quoted string for this dialect")
    }
    return str
  }
}

function parse_double_quoted_value(str) {
  return expand_value(str, DOUBLE_QUOTES)
}

function remove_optional_comment(full_value_after_equals, value_len_before_comment, is_unquoted,  comment_candidate, actual_value_part) {
  actual_value_part = substr(full_value_after_equals, 1, value_len_before_comment)
  comment_candidate = substr(full_value_after_equals, value_len_before_comment + 1)

  if (comment_candidate == "" || !match(comment_candidate, "#")) {
    sub("[ \t]+$", "", comment_candidate)
    return actual_value_part comment_candidate
  }
  space_required = 0
  if (dialect("posix|node|go|rust")) {
    space_required = 1
  } else if (dialect("python")) {
    if (is_unquoted) {
      space_required = 1
    }
  }

  if (space_required) {

    if (match(comment_candidate, "^[^ \t#]*#")) {

        if (!match(comment_candidate, "^[ \t]+#")) {
             syntax_error("spaces are required before the end-of-line comment")
        }
    }
  }

  sub("([ \t]+#.*|#.*)", "", comment_candidate)
  return actual_value_part comment_candidate
}

function output(flag, key, value) {
  if (FORMAT == "sh") output_sh(flag, key, value)
  if (FORMAT == "csh") output_csh(flag, key, value)
  if (FORMAT == "fish") output_fish(flag, key, value)
  if (FORMAT == "json") output_json(flag, key, value)
  if (FORMAT == "jsonl") output_jsonl(flag, key, value)
  if (FORMAT == "yaml") output_yaml(flag, key, value)
  if (FORMAT == "text") output_text(flag, key, value)
}

function output_sh(flag, key, value) {
  value = quotes(value)
  if (flag == ONLY_EXPORT) print "export " key
  if (flag == DO_EXPORT) print "export " key "=" value
  if (flag == NO_EXPORT) print key "=" value
}

function output_csh(flag, key, value) {
  if (match(value, /['\n]/)) {
    gsub(/[$`"\\]/, "\"'&'\"", value)
    gsub(/[\n]/, "${newline:q}", value)
    value = "\"" value "\""
  } else {
    value = "'" value "'"
  }

  if (flag == ONLY_EXPORT) print "setenv " key ";"
  if (flag == DO_EXPORT) print "setenv " key " " value ";"
  if (flag == NO_EXPORT) print "set " key "=" value ";"
}

function output_fish(flag, key, value) {
  gsub(/[\\']/, "\\\\&", value)
  if (flag == ONLY_EXPORT) print "set --export " key " \"$" key "\";"
  if (flag == DO_EXPORT) print "set --export " key " '" value "';"
  if (flag == NO_EXPORT) print "set " key " '" value "';"
}

function output_json(flag, key, value) {
  if (flag == BEFORE_ALL) {
    print "{"
    delim = ""
  } else if (flag == AFTER_ALL) {
    printf "\n}\n"
  } else if (flag == ONLY_EXPORT || flag == DO_EXPORT || flag == NO_EXPORT) {
    printf delim "  \"%s\": \"%s\"", key, json_escape(value)
    delim = ",\n"
  }
}

function output_jsonl(flag, key, value) {
  if (flag == BEFORE_ALL) {
    printf "{"
    delim = ""
  } else if (flag == AFTER_ALL) {
    print " }"
  } else if (flag == ONLY_EXPORT || flag == DO_EXPORT || flag == NO_EXPORT) {
    printf delim " \"%s\": \"%s\"", key, json_escape(value)
    delim = ","
  }
}

function output_yaml(flag, key, value) {
  if (flag == ONLY_EXPORT || flag == DO_EXPORT || flag == NO_EXPORT) {
    printf "%s: \"%s\"\n", key, json_escape(value)
  }
}

function output_text(flag, key, value) {
  if (flag == BEFORE_ALL || flag == AFTER_ALL) {
    return
  }

  if (flag == ONLY_EXPORT) {
  } else if (flag == DO_EXPORT || flag == NO_EXPORT) {
    print key "=" value
  }
}

function json_escape(value) {
  # gsub(/\\/, "\\\\", value)
  gsub(/\10/, "\\b", value)
  gsub(/\f/, "\\f", value)
  gsub(/\n/, "\\n", value)
  gsub(/\r/, "\\r", value)
  gsub(/\t/, "\\t", value)
  gsub(/["]/, "\\\"", value)
  return value
}

function process_begin() {
  output(BEFORE_ALL)
}

function process_main(export, key, value) {
  if (OVERLOAD) {
    environ[key] = value
    vars[key] = export ":" value
    if (key in defined_key) return
    defined_key[key] = FILENAME
  } else {
    if (key in defined_key) {
      msg = "%s: `%s' is already defined in the %s"
      abort(sprintf(msg, FILENAME, key, defined_key[key]))
    }
    defined_key[key] = FILENAME
    if (key in environ) return
    environ[key] = value
    vars[key] = export ":" value
  }
  defined_keys = defined_keys " " key
}

function process_finish() {
  len = split(trim(defined_keys), keys, " ")
  if (SORT) asort(keys)
  for(i = 1; i <= len; i++) {
    key = keys[i]
    if (!match(key, GREP)) continue
    match(vars[key], ":")
    export = substr(vars[key], 1, RSTART - 1)
    value = substr(vars[key], RSTART + 1)
    output(export, key, value)
  }
  output(AFTER_ALL)
}

function parse(lines) {
  SQ_VALUE = "'[^\\\\']*'?"
  DQ_VALUE = "\"(\\\\\"|[^\"])*[\"]?"
  NQ_VALUE = "[^\n]+"

  if (dialect("docker")) {
    LINE = NQ_VALUE
  } else {
    LINE = SQ_VALUE "|" DQ_VALUE "|" NQ_VALUE
  }

  while (length(lines) > 0) {
    if (sub("^[ \t\n]+", "", lines)) continue
    if (sub("^#([^\n]+)?(\n|$)", "", lines)) continue
    if (!match(lines, "^([^=\n]*=(" LINE ")?[^\n]*([\n]|$)|[^\n]*)")) {
      abort(sprintf("`%s': parse error", lines))
    }
    CURRENT_LINE = line = chomp(substr(lines, RSTART, RLENGTH))
    lines = substr(lines, RSTART + RLENGTH)
    equal_pos = index(line, "=")
    if (equal_pos == 0) {
      key = se_key_only(line)
    } else {
      key = se_key(substr(line, 1, equal_pos - 1))
    }

    if (NAMEONLY) {
      print key
    } else if (equal_pos == 0) {
      export_only_value = "" 
      export_flag = ONLY_EXPORT

      if (dialect("ruby|php")) {
      } else if (dialect("python")) {
      } else if (dialect("node|go")) {
      }
      process_main(export_flag, key, export_only_value)

    } else {
      export = (ALLEXPORT ? DO_EXPORT : NO_EXPORT) 
      original_key_part = substr(line, 1, equal_pos - 1)
      if (match(original_key_part, "^export[ \t]+")) export = DO_EXPORT

      value_after_equals = substr(line, equal_pos + 1)
      processed_value = "" 

      if (dialect("docker")) {
        processed_value = se_raw_value(value_after_equals)
      } else if (match(value_after_equals, "^"SQ_VALUE)) { 
        processed_value = remove_optional_comment(value_after_equals, RLENGTH, 0) 
        processed_value = parse_single_quoted_value(unquote(processed_value, "'"))
      } else if (match(value_after_equals, "^"DQ_VALUE)) { 
        processed_value = remove_optional_comment(value_after_equals, RLENGTH, 0)
        processed_value = parse_double_quoted_value(unquote(processed_value, "\""))
      } else {
        if (dialect("python")) {
            temp_value = value_after_equals
            
            comment_pos = 0
            stripped_leading_space_value = value_after_equals
            sub("^[ \t]+", "", stripped_leading_space_value)

            if (substr(stripped_leading_space_value, 1, 1) == "#") {
                processed_value = value_after_equals 
            } else {
                comment_marker_pos = index(value_after_equals, " #")
                
                if (comment_marker_pos > 0) {
                    part_before_comment_marker = substr(value_after_equals, 1, comment_marker_pos - 1)
                    if (trim(part_before_comment_marker) == "") {
                        processed_value = value_after_equals
                    } else {
                        processed_value = substr(value_after_equals, 1, comment_marker_pos - 1)
                    }
                } else {
                    processed_value = value_after_equals
                }
            }
            processed_value = trim(processed_value)

        } else {
            temp_val_for_len_calc = value_after_equals
            sub("[ \t]*#.*$", "", temp_val_for_len_calc) 
            val_len_for_roc = length(temp_val_for_len_calc)
            
            processed_value = remove_optional_comment(value_after_equals, val_len_for_roc, 1) 

            if (dialect("posix")) {
              processed_value = trim(processed_value) 
            } else if (dialect("ruby|go|node|php|rust")) {
              processed_value = trim(processed_value)
            }
            processed_value = parse_unquoted_value(processed_value) 
        }
      }
      process_main(export, key, processed_value)
    }
  }
}

BEGIN {
  IDENTIFIER = "[a-zA-Z_][a-zA-Z0-9_]*"
  KEEP = 1; NO_KEEP = 0
  BEFORE_ALL = 0; ONLY_EXPORT = 1; DO_EXPORT = 2; NO_EXPORT = 3; AFTER_ALL = 9
  NO_QUOTES = 0; SINGLE_QUOTES = 1; DOUBLE_QUOTES = 2

  ESCAPE["$"] = "$"
  ESCAPE["`"] = "`"
  ESCAPE["\""] = "\""
  ESCAPE["\\"] = "\\"
  ESCAPE["'"] = "'"
  ESCAPE["\n"] = ""
  ESCAPE["a"] = "\a"
  ESCAPE["b"] = "\b"
  ESCAPE["f"] = "\f"
  ESCAPE["n"] = "\n"
  ESCAPE["r"] = "\r"
  ESCAPE["t"] = "\t"
  ESCAPE["v"] = "\v"

  if (!IGNORE) {
    for (key in ENVIRON) {
      environ[key] = ENVIRON[key]
    }
  }

  if (FORMAT == "") FORMAT = "sh"
  if (!match(FORMAT, "^(sh|csh|fish|json|jsonl|yaml|text)$")) {
    abort("unsupported format: " FORMAT)
  }

  if (ARGC == 1) {
    ARGV[1] = "/dev/stdin"
    ARGC = 2
  }

  process_begin()
  for (i = 1; i < ARGC; i++) {
    FILENAME = ARGV[i]
    if (getline < FILENAME > 0) {
        lines = $0 "\n"
        if (DIALECT == "" && sub("^# dotenv ", "", $0)) DIALECT = $0
    } else {
        if (!match(FILENAME, "^(/dev/stdin|-)$")) close(FILENAME)
        continue
    }

    if (DIALECT == "") DIALECT = "posix"
    if (!dialect("posix|docker|ruby|node|python|php|go|rust")) {
      abort("unsupported dotenv dialect: " DIALECT)
    }
    while (getline < FILENAME > 0) {
      lines = lines $0 "\n"
    }
    if (!match(FILENAME, "^(/dev/stdin|-)$")) close(FILENAME)
    parse(lines)
  }
  process_finish()
  exit
}
