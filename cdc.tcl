# =============================================================================
# cdc.tcl  -  Jasper CDC script for uart_top
# Verified against ALL RTL files uploaded.
# =============================================================================
clear -all

config_rtlds -rule -enable  -category {CDC_CONFIGURATION CDC_SYNCHRONIZATION CDC_CONVERGENCE}
config_rtlds -rule -disable -category {RST_SYNCHRONIZATION HIER_CONSISTENCY}

#analyze -sv -f design.f

#**********************************ANANYA**************************************
analyze -sv -f {/home/sgeuser72/jul_cdc/rtl/design.f} ;

elaborate -top {uart_top}

# =============================================================================
# CLOCK DOMAINS
#
#  pclk         - APB bus clock (top-level input port)
#  baud_tick    - TX baud clock  = dut.tx_baud_clk  (internal net in uart_top)
#  rx_baud_clk  - RX baud clock  = dut.rx_baud_clk  (internal net in uart_top)
#
# baud_gen instance is "dut" in uart_top.
# tx_baud_clk and rx_baud_clk are outputs of baud_gen driven by
# internal FF "bclk" and "sample_cnt" logic.
# stopat -env cuts the driver so Jasper treats it as a free primary input
# satisfying rule ECK025.
# =============================================================================
clock pclk -factor 1 -phase 1

stopat -env {dut.tx_baud_clk}
clock baud_tick   -factor 1 -phase 1

stopat -env {dut.rx_baud_clk}
clock rx_baud_clk -factor 1 -phase 1

reset -expression {!presetn}

check_cdc -init


check_cdc -clock_domain -port paddr -clock_signal pclk
check_cdc -clock_domain -port psel -clock_signal pclk
check_cdc -clock_domain -port penable -clock_signal pclk
check_cdc -clock_domain -port pwrite -clock_signal pclk
check_cdc -clock_domain -port prdata -clock_signal pclk

check_cdc -clock_domain -port tx_out -clock_signal pclk
check_cdc -clock_domain -port pready -clock_signal pclk
#check_cdc -clock_domain -port pslverr -clock_signal pclk
#check_cdc -clock_domain -port pwdata -clock_signal pclk
#check_cdc -clock_domain -port rx -clock_signal pclk


# =============================================================================
# FIFO CDC SCHEMES
#
# tx_async_fifo (instance u_uart_top/u_tx_fifo):
#   - wptr_gray does NOT exist as port or internal signal.
#   - wptr_bin  is the actual internal write-pointer FF  -> use for Wptr.
#   - rptr_gray is the actual internal Gray read-pointer -> use for Rptr.
#
# rx_async_fifo (instance u_rx_top/fifo):
#   - wptr_gray = assign wptr_gray = wptr_bin ^ (wptr_bin>>1)  [internal logic]
#   - rptr_gray = assign rptr_gray = rptr_bin ^ (rptr_bin>>1)  [internal logic]
#   Both exist; map directly.
# =============================================================================
check_cdc -scheme -add FIFO -module tx_async_fifo \
    -map {{Wdata data_in}     {Winc write_enable} \
          {Wfull fifo_full}   {Wptr wptr_bin}     \
          {Rdata data_out}    {Rinc read_enable}  \
          {Rempty fifo_empty} {Rptr rptr_gray}}

check_cdc -scheme -add FIFO -module rx_async_fifo \
    -map {{Wdata data_in}   {Winc write_enable} \
          {Wfull rx_full}   {Wptr wptr_gray}    \
          {Rdata data_out}  {Rinc data_rd_en}   \
          {Rempty rx_empty} {Rptr rptr_gray}}



check_cdc -scheme -add NDFF -module ndff_sync -map {{Data data_in} {Dout data_out}}

check_cdc -scheme -add NDFF -module thr -map {{Data tgl_r} {Dout tgl_w2}}

#check_cdc -scheme -add NDFF -module lcr -map {{Data data_in} {Dout data_out}}

#check_cdc -scheme -add NDFF -module wls -map {{Data data_in} {Dout data_out}}

#check_cdc -scheme -add NDFF_BUS -module lcr -map {{Data data_in} {Dout data_out}}

#check_cdc -scheme -add NDFF_BUS -module wls -map {{Data data_in} {Dout data_out}}

#check_cdc -scheme -add NDFF_BUS -module  mdr -map {{Data data_in} {Dout data_out}}
# =============================================================================
# CDC ANALYSIS PASSES
# =============================================================================
check_cdc -clock_domain   -find
check_cdc -pair           -find
check_cdc -scheme         -find
check_cdc -group          -find
check_cdc -protocol_check -generate
check_cdc -metastability  -inject
check_cdc -reset          -find

config_rtlds -rule -disable -tag SYN_DF_FOUT


check_cdc -waiver -add -filter [check_cdc -filter -add -regexp -check cdc_pair_logic -violation Pair -occurrence {u_uart_top\.u_thr\.tgl_w1}] -comment { That pair logic is an design intended as per the specification given that: THR must be reset when the FCR[2] is "1". For that, after reset we have to that aspect as well. While checking that condition combo logic (Mux) is detected.}

# =============================================================================
# WAIVERS
#
# CONFIRMED HIERARCHY from uart_top.sv:
#   uart_top
#   +-- dut_fcr1       (fcr)          signals: gray_data, stage2
#   +-- dut_lcr        (lcr)
#   +-- rxx            (ndff_sync1)   signals: stage1, stage2
#   +-- dut            (baud_gen)     signals: bclk, bclk_cnt, sample_cnt, tx_baud_clk, rx_baud_clk
#   +-- u_uart_top     (tx_top)
#   ¦   +-- u_demux        (demux)
#   ¦   +-- u_thr          (thr)      signals: tgl_r, tgl_w1, tgl_w2, tsr_pulse_w, thr_data_out
#   ¦   +-- u_tx_fifo      (tx_async_fifo)  signals: wptr_bin, rptr_gray
#   ¦   +-- u_mux          (mux)
#   ¦   +-- u_sync_pen     (ndff_sync)
#   ¦   +-- dut_wls        (wls)
#   ¦   +-- u_tsr_controler(tsr_controler) signals: present_state, tx_out, tsr_empty_sync1, tsr_empty_sync
#   ¦   +-- u_piso         (piso)     signals: shift_reg
#   ¦   +-- u_parity_gen   (parity)   signals: parity_out
#   ¦   +-- u_stop_gen     (stop_gen) signals: shift_reg, bit2_phase
#   +-- u_rx_top       (rx_top)
#   ¦   +-- core           (rx_fsm)
#   ¦   +-- fifo           (rx_async_fifo)  signals: wptr_gray, rptr_gray
#   ¦   +-- rbr            (rbr)      signals: wr_req_tog, ack_tog, ack_w1, ack_wsync, ack_wprev
#   ¦                                          shadow_data, rbr_data_out, empty_r1, empty_rsync
#   +-- u_regs         (regs)
#       +-- u_sync_rx_empty    (ndff_sync)
#       +-- u_sync_rx_full     (ndff_sync)
#       +-- u_sync_parity_err  (ndff_sync)
#       +-- u_sync_framing_err (ndff_sync)
#       +-- u_sync_overrun_err (ndff_sync)
#       +-- u_sync_break_int   (ndff_sync)
#       +-- u_sync_tsr_empty   (ndff_sync)
#       +-- u_sync_tsr_shift   (ndff_sync)
#       +-- u_sync_tx_full     (ndff_sync)
# =============================================================================

# -----------------------------------------------------------------------------
# FCR Gray-code CDC (pclk -> rx_baud_clk)
# dut_fcr1 is instance of fcr module.
# gray_data is the Gray-coded FF in pclk domain.
# stage2 is the capture FF in rx_baud_clk domain.
# This is a proper single-FF Gray-code crossing - waive pair/no_scheme violations.
# -----------------------------------------------------------------------------
#

#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check unclocked_signal \
#             -occurrence {paddr}] \
#    -comment {paddr: APB primary input, driven synchronously by APB master in pclk domain}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check unclocked_signal \
#             -occurrence {psel}] \
#    -comment {psel: APB primary input, driven synchronously by APB master in pclk domain}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check unclocked_signal \
#             -occurrence {penable}] \
#    -comment {penable: APB primary input, driven synchronously by APB master in pclk domain}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check unclocked_signal \
#             -occurrence {pwrite}] \
#    -comment {pwrite: APB primary input, driven synchronously by APB master in pclk domain}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check unclocked_signal \
#             -occurrence {prdata\[8:0\]}] \
#    -comment {prdata[8:0]: APB read-data output, combinational from pclk-domain regs logic - reported unclocked as top-level output port}
#
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check unclocked_signal \
#             -occurrence {pready}] \
#    -comment {pready: APB ready output, combinational from pclk-domain logic}
#
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {dut_fcr1\.gray_data}] \
#    -comment {FCR Gray-coded CDC: gray_data is Gray-encoded in pclk domain, stage2 captures in rx_baud_clk - safe 1-bit-change-per-cycle crossing}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check cdc_pair_fanout -violation Pair \
#             -occurrence {dut_fcr1\.gray_data}] \
#    -comment {FCR Gray-code fanout: each bit changes at most once per transition - safe}
#
## -----------------------------------------------------------------------------
## LCR sync (pclk -> rx_baud_clk) - same structure as FCR
## -----------------------------------------------------------------------------
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {dut_lcr\.gray_data}] \
#    -comment {LCR Gray-coded CDC: gray_data pclk domain -> rx_baud_clk domain - safe Gray crossing}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check cdc_pair_fanout -violation Pair \
#             -occurrence {dut_lcr\.gray_data}] \
#    -comment {LCR Gray-code fanout: safe, only 1 bit changes per transition}
#
## -----------------------------------------------------------------------------
## FCR_OUT in uart_top (pclk domain, registered in u_regs)
## FCR_OUT_REG is the raw binary, FCR_OUT is Gray-decoded.
## These drive sel and tx_clr which go to tx_top (baud_tick domain).
## -----------------------------------------------------------------------------
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {FCR_OUT_REG}] \
#    -comment {FCR_OUT_REG: pclk->baud_tick; downstream tx_clr and sel are quasi-static config signals, stable before TX activity}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check cdc_pair_fanout -violation Pair \
#             -occurrence {FCR_OUT_REG}] \
#    -comment {FCR_OUT_REG fanout to sel/tx_clr: config signals, written once before use}
#
## -----------------------------------------------------------------------------
## rbr toggle handshake signals (clk_w=rx_baud_clk <-> clk_r=pclk)
## ACTUAL signal names verified from rbr.sv:
##   wr_req_tog  - toggle FF in clk_w domain
##   ack_tog     - toggle FF in clk_r domain
##   ack_w1      - 2-FF sync stage 1 in clk_w
##   ack_wsync   - 2-FF sync output in clk_w
##   ack_wprev   - edge-detect delay FF in clk_w
##   shadow_data - data FF in clk_w, read clk_r after handshake
##   rbr_data_out- output FF in clk_r
##   empty_r1    - 2-FF sync stage 1 for rbr_empty1 in clk_r
##   empty_rsync - 2-FF sync output for rbr_empty1 in clk_r
## -----------------------------------------------------------------------------
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_rx_top\.rbr\.wr_req_tog}] \
#    -comment {rbr wr_req toggle: clk_w->clk_r crossing via ack_tog toggle-handshake protocol - safe}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_rx_top\.rbr\.ack_tog}] \
#    -comment {rbr ack_tog: clk_r->clk_w crossing synchronized by ack_w1/ack_wsync 2-FF chain - safe}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_rx_top\.rbr\.ack_w1}] \
#    -comment {rbr ack_w1: 2-FF sync stage 1 for ack_tog in clk_w - correct synchronizer FF}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_rx_top\.rbr\.ack_wsync}] \
#    -comment {rbr ack_wsync: 2-FF sync output for ack_tog in clk_w - synchronized}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_rx_top\.rbr\.ack_wprev}] \
#    -comment {rbr ack_wprev: edge-detect delay FF, same clk_w domain - no CDC crossing}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_rx_top\.rbr\.shadow_data}] \
#    -comment {rbr shadow_data: written in clk_w; read in clk_r only after full toggle handshake completes - safe}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_rx_top\.rbr\.rbr_data_out}] \
#    -comment {rbr_data_out: captured in clk_r only when wr_req_tog handshake is acknowledged - safe}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_rx_top\.rbr\.empty_r1}] \
#    -comment {rbr empty_r1: 2-FF sync stage 1 for rbr_empty1 into clk_r - correct synchronizer}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_rx_top\.rbr\.empty_rsync}] \
#    -comment {rbr empty_rsync: 2-FF sync output for rbr_empty1 in clk_r - synchronized, safe}
#
## -----------------------------------------------------------------------------
## TX datapath signals - all clocked on baud_tick (clk_r of tx_top)
## No actual CDC crossing - Jasper false-positive due to NDFF scheme detection.
## -----------------------------------------------------------------------------
#
## piso shift_reg - load/shift from tsr_data_out; all in baud_tick
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_uart_top\.u_piso\.shift_reg}] \
#    -comment {piso shift_reg: clocked on baud_tick same as all TX datapath - no CDC crossing}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check sync_chain_fanout -violation Scheme \
#             -occurrence {u_uart_top\.u_piso\.shift_reg}] \
#    -comment {False positive: piso shift_reg and source thr_data_out both on baud_tick - no CDC}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check sync_chain_logic -violation Scheme \
#             -occurrence {u_uart_top\.u_piso\.shift_reg}] \
#    -comment {False positive: piso shift_reg and source thr_data_out both on baud_tick - no CDC}
#
## tsr_controler present_state - enum FF, clocked on baud_tick
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_uart_top\.u_tsr_controler\.present_state}] \
#    -comment {present_state: state enum FF clocked on baud_tick - no CDC, all TX logic same clock}
#
## tsr_controler tx_out - registered FF on baud_tick (fixed in RTL with always_ff)
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_uart_top\.u_tsr_controler\.tx_out}] \
#    -comment {tx_out: registered FF on baud_tick - no CDC crossing}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check sync_chain_logic -violation Scheme \
#             -occurrence {u_uart_top\.u_tsr_controler\.tx_out}] \
#    -comment {False positive: tx_out registered on baud_tick; parity_out/data_bit/stop_bit all same domain}
#
## parity_out - registered on baud_tick inside parity module
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_uart_top\.u_parity_gen\.parity_out}] \
#    -comment {parity_out: clocked on baud_tick - no CDC crossing}
#
## stop_gen shift_reg and bit2_phase - both on baud_tick
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_uart_top\.u_stop_gen\.shift_reg}] \
#    -comment {stop_gen shift_reg: clocked on baud_tick - no CDC crossing}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_uart_top\.u_stop_gen\.bit2_phase}] \
#    -comment {stop_gen bit2_phase: clocked on baud_tick - no CDC crossing}
#
## thr_data_out and toggle sync FFs (tgl_r, tgl_w1, tgl_w2)
## thr.sv verified: tgl_r (baud_tick) -> tgl_w1 -> tgl_w2 (pclk)
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_uart_top\.u_thr\.thr_data_out}] \
#    -comment {thr_data_out: captured in baud_tick only when tgl_r toggle handshake completes - safe}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check sync_chain_logic -violation Scheme \
#             -occurrence {u_uart_top\.u_thr\.tgl_w1}] \
#    -comment {thr tgl_w1: 2-FF sync stage 1, tgl_r(baud_tick)->pclk - correct synchronizer FF, no logic between stages}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check sync_chain_logic -violation Scheme \
#             -occurrence {u_uart_top\.u_thr\.tgl_w2}] \
#    -comment {thr tgl_w2: 2-FF sync output; tsr_pulse_w downstream comb logic is after sync output, not between FF stages}
#
## tsr_empty CDC path: tsr_empty (baud_tick, output of tx_top) ->
## u_regs/u_sync_tsr_empty (ndff_sync in pclk) - already has proper 2-FF sync
## and inside tsr_controler another 2-FF sync (tsr_empty_sync1/tsr_empty_sync)
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_uart_top\.u_tsr_controler\.tsr_empty_sync1}] \
#    -comment {tsr_empty_sync1: 2-FF sync stage 1 for tsr_empty into baud_tick - correct synchronizer}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_uart_top\.u_tsr_controler\.tsr_empty_sync}] \
#    -comment {tsr_empty_sync: 2-FF sync output for tsr_empty in baud_tick - synchronized, safe}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check convergence_check -violation Convergence \
#             -occurrence {u_regs\.FCR_OUT1}] \
#    -comment {False positive: FCR_OUT1 driven only on ADDR_FCR case arm in single pclk-domain always_ff; case arms are mutually exclusive via paddr_r decode, write_en/addr_valid gates all single-clock - no real CDC convergence}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check convergence_check -violation Convergence \
#             -occurrence {u_regs\.FCR_OUT}] \
#    -comment {False positive: psel/penable/pwrite are synchronous APB primary inputs in pclk domain, reported unclocked only because they are top-level ports with no internal driver visible to the tool}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check convergence_check -violation Convergence \
#             -occurrence {u_regs\.FCR_OUT1}] \
#    -comment {Same root cause as FCR_OUT - psel/penable/pwrite unclocked primary input false positive}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check convergence_check -violation Convergence \
#             -occurrence {u_regs\.LCR_OUT}] \
#    -comment {Same root cause as FCR_OUT - psel/penable/pwrite unclocked primary input false positive}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check convergence_check -violation Convergence \
#             -occurrence {u_regs\.LCR_OUT1}] \
#    -comment {Same root cause as FCR_OUT - psel/penable/pwrite unclocked primary input false positive}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check convergence_check -violation Convergence \
#             -occurrence {u_regs\.DLL_OUT}] \
#    -comment {Same root cause as FCR_OUT - psel/penable/pwrite unclocked primary input false positive}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check convergence_check -violation Convergence \
#             -occurrence {u_regs\.DLH_OUT}] \
#    -comment {Same root cause as FCR_OUT - psel/penable/pwrite unclocked primary input false positive}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check convergence_check -violation Convergence \
#             -occurrence {u_regs\.MDR_OUT}] \
#    -comment {Same root cause as FCR_OUT - psel/penable/pwrite unclocked primary input false positive}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check reconvergence_check -violation Convergence \
#             -occurrence {u_uart_top\.u_thr\.thr_data_out}] \
#    -comment {By design: tx_clr (FCR_OUT[3:2]) and sel (FCR_OUT[1:0]) are intentionally split into independent 2-FF synchronizers (tx_clr_r1/tx_clr_rsync and u_sync_sel.stage1) per architecture. FCR_OUT is a quasi-static config register written once during UART init before TX activity; firmware does not modify it during active transmission. Independent-synchronizer bit-skew between tx_clr and sel cannot occur under this usage model - waived per design intent}
#
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check convergence_check -violation Convergence \
#             -occurrence {u_uart_top\..*}] \
#    -comment {By design: all FCR_OUT/LCR_OUT config bit-fields are intentionally split into independent per-bit synchronizers across u_thr, u_sync_sel, u_sync_pen, dut_wls, u_stop_gen, u_tsr_controler. Quasi-static config, no concurrent write during active TX - waived per design intent for entire u_uart_top (tx_top) hierarchy}
#
#
## pen (pclk domain) -> u_sync_pen (ndff_sync in baud_tick) - already proper 2-FF
## parity_en_sync1/parity_en_sync inside tsr_controler are also a 2-FF sync
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_uart_top\.u_tsr_controler\.parity_en_sync1}] \
#    -comment {parity_en_sync1: 2-FF sync stage 1 for pen into baud_tick inside tsr_controler}
#
#check_cdc -waiver -add \
#    -filter [check_cdc -filter -add -regexp -check no_scheme -violation Pair \
#             -occurrence {u_uart_top\.u_tsr_controler\.parity_en_sync}] \
#    -comment {parity_en_sync: 2-FF sync output for pen in baud_tick - synchronized}
#
# =============================================================================
get_clock_info -gui
