#!/usr/bin/env bash
set -e

#-- 変数定義 --#
current_dir=$(cd $(dirname ${0}) && pwd)
current_path=$(cd $(dirname ${0}) && pwd)/$(basename ${0})
os_name="serenelinux"
extention="iso"
api_url="https://api.s.0u0.biz/w.php"
auth_file=${current_dir}/auth
cli_mode=false
window_icon=
window_text="SereneLinux ビルド番号ジェネレーター"

#-- GUI 関数 --#
# ウィンドウの基本型
function window () { zenity --title="${window_text}" --window-icon="${window_icon}" ${@}; }
# 読み込みウィンドウ
function loading () { window --progress --auto-close --pulsate --width="${1}" --height="${2}" --text="${3}"; }
# エラーウィンドウ
function error () { window --error --width="${1}" --height="${2}" --text="${3}"; }
# 警告ウィンドウ
function warning () { window --warning --width="${1}" --height="${2}" --text="${3}"; }
# 情報ウィンドウ
function info () { window --info --width="${1}" --height="${2}" --text="${3}"; }
# CLI エラー
function error_cli () { echo -e ${@} >&2; }
# ヘルプ
function usage () {
    echo "SereneLinux ビルド番号ジェネレーター"
    echo
    echo " -u [str] : ユーザー名を指定します。"
    echo " -p [str] : パスワードを指定します。"
    echo " -h       : このヘルプを表示します。"
    echo " -c       : CLIモードで動作します。"
    echo " -g       : GUIモードで動作します。"
    echo " -f       : 認証ファイルを指定します。"
}

#-- 引数解析 --#
while getopts 'u:p:hcgf:' arg; do
    case "${arg}" in
        u) auth_user="${OPTARG}" ;;
        p) auth_pass="${OPTARG}" ;;
        h) usage; exit 0 ;;
        c) cli_mode=true ;;
        g) cli_mode=false ;;
        f) auth_file="${OPTARG}" ;;
        *) usage; exit 1 ;;
    esac
done

#-- 認証情報 --#
function auth () {
    if [[ ${cli_mode} = true ]]; then
        while [ -z ${auth_user} ]; do
            echo -n "ユーザー名を入力してください。： "
            read auth_user
        done
        while [ -z ${auth_pass} ]; do
            echo -n "パスワードを入力してください。： "
            read -s auth_pass
            echo
        done
    else
        while true; do
            auth_full=$(
                window \
                    --forms \
                    --separator='|' \
                    --text="認証情報を入力してください。" \
                    --add-entry="ユーザ名" \
                    --add-password="パスワード" 
            )
            auth_full=${auth_full//'|'/' '}
            auth_user=$(echo ${auth_full} | awk '{print $1}')
            auth_pass=$(echo ${auth_full} | awk '{print $2}')
            if [[ -n ${auth_user} && -n ${auth_pass} ]]; then
                break
            fi
        done
    fi
}

[[ -f ${auth_file} ]] && source ${auth_file}
[[ -z ${auth_user} || -z ${auth_pass} ]] && auth

#-- 情報生成 --#
build_info=$(curl -s -u ${auth_user}:${auth_pass} ${api_url} -d url=${url}) > /dev/null
version=$(echo ${build_info} | awk '{print $2}')
name="${os_name}_${version}.${extention}"

#-- 認証チェック --#
function auth_failed () {
    [[ ${cli_mode} = true ]] && error_cli "認証に失敗しました。"
    [[ ${cli_mode} = false ]] && error 500 100 "認証に失敗しました。"
    return 1
    bash ${current_path} ${@}
}

function server_failed () {
    [[ ${cli_mode} = true ]] && error_cli "サーバに問題が発生しました。"
    [[ ${cli_mode} = false ]] && error 500 100 "サーバに問題が発生しました。"
    exit 3
}

function unknown () {
    [[ ${cli_mode} = true ]] && error_cli "不明なエラーが発生しました。"
    [[ ${cli_mode} = false ]] && error 500 100 "不明なエラーが発生しました。"
    exit 255
}

if [[ ${build_info} == *"-Error"* ]]; then
    error=${build_info}
    error=${error//""-Error""/}
    #echo $error

    case ${error} in
        401) auth_failed;;
        403) server_failed;;
          *) unknown ;; 
    esac
else
    [[ $cli_mode = false ]] && info 500 100 "イメージファイル名は「${name}」です。"
    echo ${name}
    exit 0
fi