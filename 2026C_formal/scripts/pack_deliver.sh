#!/usr/bin/env bash
# pack_deliver.sh —— 按"交付附件命名与结构规范"打包 deliver/
#
#   每问一个「问题X对应的代码与说明」文件夹，内含该问入口程序 + 依赖子函数副本 + 说明文档(docx)；
#   顶层放人工筛选后的关键结果图（jpg）。论文源程序、论文.pdf、AI工具使用说明.pdf 由论文手/全队提供，
#   本脚本不生成，只在收尾提示补入。
#
#   说明文档正文从 scripts/deliver_text/qX.txt 读取（自然段落、不含命令与目录树），
#   由 scripts/make_docx.py 转成 docx。
#
#   用法：bash scripts/pack_deliver.sh
set -u
cd "$(dirname "$0")/.."
SRC=src
DST=deliver
TXT=scripts/deliver_text
mkdir -p "$DST"

pack() {                       # $1=文件夹名  $2=说明标题  $3=文本文件  $4..=代码文件名
    # src/ 自 2026-09-13 起按问分目录（src/问题X/ 与 src/共用/），故按**文件名递归查找**；
    # 交付文件夹保持**平铺**（评审打开即可读，MATLAB 同目录自动解析兄弟函数）。
    local dir="$DST/$1"  title="$2"  text="$3"; shift 3
    mkdir -p "$dir"
    local n=0
    for f in "$@"; do
        local hit
        hit=$(find "$SRC" -name "$f" -not -path "*_旧版_勿引用*" -print -quit 2>/dev/null)
        if [ -n "$hit" ]; then cp -a "$hit" "$dir/"; n=$((n+1))
        else echo "  [警告] 缺少 $SRC/**/$f"; fi
    done
    # 交付副本与子函数同目录，不需要再挂 src 路径（否则评审运行时会看到一条空路径告警）
    python3 scripts/flatten_deliver_code.py "$dir" >/dev/null
    echo "  代码 $n 个 → $dir"
    if [ -f "$text" ]; then
        python3 scripts/make_docx.py "$text" "$dir/${title}.docx" "$title"
    else
        echo "  [警告] 缺少说明文本 $text（docx 未生成）"
    fi
}

put() {                        # $1=输出目录  $2=源文件  $3=交付文件名
    if [ -f "$2" ]; then cp -a "$2" "$DST/$1/$3"; echo "  结果表 $3 → $DST/$1/"
    else echo "  [警告] 缺少结果表 $2"; fi
}

echo "=== 打包 deliver/ ==="

pack "问题一对应的代码与说明" "问题一_代码说明" "$TXT/q1.txt" \
    main_q1.m func_build_q1.m func_check_q1.m func_read_q1.m func_write_q1.m \
    func_fig_pal.m func_fig_style.m
put "问题一对应的代码与说明" outputs/result1.xlsx result1.xlsx

pack "问题二对应的代码与说明" "问题二_代码说明" "$TXT/q2.txt" \
    main_q2c.m func_read_q2.m func_forecast_q2.m func_bias_q2.m func_resid_q2.m \
    func_build_q2c.m func_scen_q2c.m func_exec_q2c.m func_roll_q2c.m func_write_q2.m \
    func_fig_pal.m func_fig_style.m
put "问题二对应的代码与说明" outputs/result2_q2c.xlsx result2.xlsx

pack "问题三对应的代码与说明" "问题三_代码说明" "$TXT/q3.txt" \
    main_q3b.m func_read_q3b.m func_interp_q3b.m func_resid_q3b.m func_build_q3b.m \
    func_scen_q3b.m func_exec_q3b.m func_roll_q3b.m func_read_q2.m func_forecast_q2.m \
    func_bias_q2.m func_resid_q2.m func_write_q2.m func_fig_pal.m func_fig_style.m
put "问题三对应的代码与说明" outputs/result3.xlsx result3.xlsx

pack "问题四对应的代码与说明" "问题四_代码说明" "$TXT/q4.txt" \
    main_q4.m func_price_q4.m func_scen_q4.m func_roll_q4.m func_build_q3b.m \
    func_exec_q3b.m func_read_q3b.m func_interp_q3b.m func_resid_q3b.m func_read_q2.m \
    func_forecast_q2.m func_bias_q2.m func_resid_q2.m func_write_q2.m \
    func_fig_pal.m func_fig_style.m
put "问题四对应的代码与说明" outputs/result4-2.xlsx result4-2.xlsx
put "问题四对应的代码与说明" outputs/result4-3.xlsx result4-3.xlsx

echo
echo "=== 顶层关键结果图（人工筛选后的选图清单见 scripts/make_top_figs.py） ==="
python3 scripts/make_top_figs.py

echo
echo "=== 交付目录现状 ==="
find "$DST" -maxdepth 2 | sort | head -40
echo
echo "提示：论文源程序/、论文.pdf、AI工具使用说明.pdf 不由本脚本生成，收尾时请全队补入。"
