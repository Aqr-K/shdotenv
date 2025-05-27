[简体中文](README.md) | [English](README.en.md)

# shdotenv

为 shell 设计的 dotenv 工具，支持 POSIX 兼容及多种 .env 文件语法

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/Aqr-K/shdotenv/ubuntu.yml?branch=main&logo=github)

**项目状态**：基本完成。主要功能已实现，v1.0.0 版本将在近期发布。

引用 [bkeepers/dotenv][dotenv] 的话：

> 将[配置存储在环境](http://12factor.net/config)中是[十二要素应用](http://12factor.net)的信条之一。任何可能在部署环境之间发生变化的东西——例如数据库的资源句柄或外部服务的凭据——都应该从代码中提取到环境变量中。

[dotenv]: https://github.com/bkeepers/dotenv

## 为什么不使用 `source` 或 `export`？

这不安全。.env 文件语法没有正式的规范，不同的语言、库和工具使用不同的语法。如果您加载了与 POSIX shell 语法不兼容的 .env 文件语法，将会得到意外的结果，甚至可能导致脚本执行。

shdotenv 可以安全地加载与 POSIX shell 语法兼容的 .env 文件。脚本不可能被执行。此外，为了互操作性，尽可能支持其他语法的 .env 文件。

## 本项目目标

1.  提供语言无关的 CLI 工具
2.  提供一个可以从 shell 脚本安全加载 .env 文件的库
3.  定义 POSIX shell 兼容的 .env 文件语法规范
4.  支持 .env 文件语法编程语言以实现互操作性

## 要求

`shdotenv` 是一个嵌入了 awk 脚本的单文件 shell 脚本。它只使用以下随处可见的命令：

- POSIX shell (dash, bash, ksh, zsh 等)
- awk (gawk, nawk, mawk, busybox awk)

## 安装

从 [releases](https://github.com/Aqr-K/shdotenv/releases) 下载 `shdotenv` (shell 脚本)。

```console
$ mkdir -p "$HOME/bin"
$ wget https://github.com/Aqr-K/shdotenv/releases/latest/download/shdotenv -O "$HOME/bin/shdotenv"
$ chmod +x "$HOME/bin/shdotenv"
```

如果您偏好 XDG 基本目录规范，可以将其安装在 `$HOME/.local/bin` 目录下。

```console
$ mkdir -p "$HOME/.local/bin"
$ wget https://github.com/Aqr-K/shdotenv/releases/latest/download/shdotenv -O "$HOME/.local/bin/shdotenv"
$ chmod +x "$HOME/.local/bin/shdotenv"
```

不要忘记将安装目录添加到 `PATH` 环境变量中。

### 自行构建

**仅构建和安装**

```console
$ git clone https://github.com/Aqr-K/shdotenv.git
$ cd shdotenv
$ make
$ make install PREFIX=$HOME
```

**完整构建（测试并生成小型构建版本）**

完整构建需要 [shfmt](https://github.com/mvdan/sh)、[shellcheck](https://github.com/koalaman/shellcheck) 和 [shellspec](https://github.com/shellspec/shellspec)。

```console
$ git clone https://github.com/Aqr-K/shdotenv.git
$ cd shdotenv
$ make all MINIFY=true
$ make install PREFIX=$HOME
```

**开发者注意**：`shdotenv` 可以在源代码中直接运行，无需构建。请运行 `src/shdotenv`。

## 用法

```
Usage: shdotenv [OPTION]... [--] [[COMMAND | export] [ARG]...]

  If the COMMAND is specified, it will load .env files and run the command.
  If the COMMAND is omitted, it will output the result of interpreting .env
  files. It can be safely loaded into the shell (For example, using eval).

Options:
  -d, --dialect DIALECT     Specify the .env dialect [default: posix]
                                posix, ruby, node, python,
                                php, go, rust, docker
  -f, --format FORMAT       Output in the specified format [default: sh]
                                sh, csh, fish, json, jsonl, yaml
  -e, --env ENV_PATH        Location of the .env file [default: .env]
                              Multiple -e options are allowed
                              If the ENV_PATH is "-", read from stdin
  -i, --ignore-environment  Ignore the current environment variables
      --overload            Overload predefined variables
      --no-allexport        Disable all variable export
      --no-nounset          Allow references to undefined variables
      --grep PATTERN        Output only names that match the regexp pattern
  -s, --sort                Sort variable names
  -q, --quiet               Suppress all output (useful for test .env files)
      --version             Show the version and exit
      --help                Show this message and exit

Usage: shdotenv [OPTION]... export [-0ps] [-n | -v] [--] [NAME]...
  Exports environment variables. Default output is POSIX-compliant .env format.

  -0  end each output line with NUL, not newline
  -p  Append "export" prefix to environment variable names
  -s  Empty string instead of error if name is missing
  -n  List environment variable names only
  -v  List environment variable values only

  This will be output after the .env files is loaded. If you do not want
  to load it, specify "-e /dev/null". This is similar to "export", "env"
  and "printenv" commands, but quoting correctly and exports only portable
  environment variable name that are valid as identifier for posix shell.
```

## 如何使用

### 作为 CLI 工具使用

设置环境变量并执行指定的命令。

```sh
shdotenv [选项]... <命令> [参数]...
```

#### 测试 .env 文件语法

```sh
shdotenv --quiet --env .env
```

### 作为库使用

将 .env 文件加载到 shell 脚本中。在 shell 中运行时，它会导出到当前 shell。

#### sh, bash, ksh, zsh 等 (POSIX 兼容 shell)

```sh
eval "$(shdotenv [选项]...)"
```

您可能希望在 `.env` 文件解析失败时中止程序。这种情况下，请执行以下操作：

```sh
eval "$(shdotenv [选项]... || echo "exit $?")"
```

#### csh, tcsh

```tcsh
set newline='\
'
eval "`shdotenv -f csh [选项]...`"
```

#### fish

```fish
eval (shdotenv -f fish [选项]...)
```

### 安全地导出环境变量

这类似于 `export`、`env` 和 `printenv` 命令，但会正确引用，并且只导出对 POSIX shell 有效的便携式环境变量名称。

```text
shdotenv [选项]... export [选项]... [名称]...
```

## 如何与 docker 协同工作

`docker` 命令有 `--env-file` 选项，但它只支持设置不含换行符的简单值。

- [docker cannot pass newlines from variables in --env-file files](https://github.com/moby/moby/issues/12997)

shdotenv 为此问题提供了一个简单的解决方案。

```sh
shdotenv docker run $(shdotenv -n | sed s/^/-e/) debian sh -c export
```

## .env 文件语法

```sh
# dotenv posix
# 这是一个注释行，上面一行是指示指令
COMMENT=This-#-is-a-character # 这是一个注释

UNQUOTED=value1 # 不能使用空格和一些特殊字符
SINGLE_QUOTED='value 2' # 不能使用单引号
DOUBLE_QUOTED="value 3" # 一些特殊字符需要转义

MULTILINE="line1
line2: \n is not a newline
line3"
LONGLINE="https://github.com/Aqr-K\
/shdotenv/blob/main/README.md"

ENDPOINT="http://${HOST}/api" # 变量展开需要花括号

export EXPORT1="value"
export EXPORT2 # 等同于：export EXPORT2="${EXPORT2:-}"
```

- 语法是 POSIX shell 的一个子集
- 第一行是可选的指示指令，用于指定 .env 语法的编程语言
- 分隔名称和值的 `=` 前后不允许有空格
- 不支持 ANSI-C 风格的转义（即 `\n` 不是换行符）
- **无引号值**
  - 可以使用的特殊字符是 `#` `%` `+` `,` `-` `.` `/` `:` `=` `@` `^` `_`
  - 无引号值的首字符不允许是 `=` (0.14.0 版本新增)
- **单引号值**
  - 不允许的字符是：`'`
  - 它可以包含换行符
- **双引号值**
  - 支持变量展开（仅支持 `${VAR}` 样式）
  - 以下值应使用反斜杠 (`\`) 转义：`$` <code>\`</code> `"` `\`
  - 行尾的 `\` 表示行连接
  - 它可以包含换行符
- 名称前可以添加可选的 `export` 前缀
- 行尾注释的 `#` 前需要有空格

详细的 [POSIX 兼容 .env 语法规范](docs/specification.md)

### 指示指令

指定此 `.env` 文件使用的 dotenv 语法编程语言。

```sh
# dotenv <编程语言>
```

示例：

```sh
# dotenv ruby
```

### 支持的编程语言

本项目的正式 `.env` 语法仅为 `posix`。`posix` 是 POSIX shell 的一个子集，并与 shell 脚本兼容。支持其他 .env 语法编程语言是为了互操作性。兼容性将逐步提高，但并非完全兼容。欢迎报告问题。

- docker: [docker](https://docs.docker.com/engine/reference/commandline/run/#set-environment-variables--e---env---env-file)
- ruby: [dotenv](https://github.com/bkeepers/dotenv)
- node: [dotenv](https://github.com/motdotla/dotenv) + [dotenv-expand](https://github.com/motdotla/dotenv-expand)
- python: [python-dotenv](https://github.com/theskumar/python-dotenv)
- php: [phpdotenv](https://github.com/vlucas/phpdotenv)
- go: [godotenv](https://github.com/joho/godotenv)
- rust: [dotenv](https://github.com/dotenv-rs/dotenv)

[比较编程语言](docs/dialects.md)

## .shdotenv

指定 shdotenv 的选项。目前仅支持 `dialect`。建议使用 `dotenv` 指示指令指定 dotenv 编程语言。`.shdotenv` 设置适用于不允许修改项目文件但个人需要指定编程语言的情况。

```
dialect: <编程语言>
```

示例：

```
dialect: ruby
```

## 环境变量

| 名称            | 描述                       | 默认值 |
| --------------- | -------------------------- | ------ |
| SHDOTENV_FORMAT | 输出格式 (`sh`, `fish` 等) | `sh`   |
| SHDOTENV_AWK    | `awk` 命令的路径           | `awk`  |

## 常见问题解答 (FAQ)

**注意和参考**：[motdotla 的 dotenv](https://github.com/motdotla/dotenv#faq) 项目页面和 [cdimascio 的 dotenv-java](https://github.com/cdimascio/dotenv-java#faq) 项目页面上的 FAQ 写得非常好，我已将相关的 FAQ 包含在上面。

### 问：我应该将 .env 文件部署到例如生产环境吗？

答：[十二要素应用方法论](https://12factor.net/config)的第三条原则指出：“十二要素应用将配置存储在环境变量中”。因此，不建议将 .env 文件提供给此类环境。然而，dotenv 在例如本地开发环境中非常有用，因为它使开发人员能够通过文件管理环境，这更加方便。

在生产环境中使用 dotenv 是一种“作弊”行为。然而，这种用法是一种反模式。

### 问：我应该提交我的 .env 文件吗？

答：不。我们**强烈**建议不要将您的 `.env` 文件提交到版本控制系统。它应该只包含特定于环境的值，例如数据库密码或 API 密钥。您的生产数据库应该使用与开发数据库不同的密码。

### 问：已经设置的环境变量会怎么样？

答：默认情况下，我们绝不会修改任何已经设置的环境变量。特别是，如果您的 `.env` 文件中的变量与环境中已存在的变量冲突，则该变量将被跳过。

如果您想覆盖环境变量，请使用 `--overload` 选项。

```sh
shdotenv --overload
```

### 问：为什么我不能在 .env 文件中定义同名环境变量？

答：为了方便性和与其他 dotenv 工具的互操作性，我们允许多个 .env 文件。然而，我们认为在不同的 .env 文件中使用相同的名称会导致环境变量不像[十二要素应用](https://12factor.net/config)所概述的那样“完全正交”。

> 在十二要素应用中，环境变量是细粒度的控件，每个都与其他环境变量完全正交。它们从不被组合成“环境”，而是为每个部署独立管理。这是一个随着应用在其生命周期中自然扩展到更多部署而平稳扩展的模型。
>
> – 十二要素应用

如果您想覆盖先前的定义，请使用 `--overload` 选项。
