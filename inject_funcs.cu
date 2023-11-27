#include <stdint.h>
#include <stdio.h>

#include "utils/utils.h"
#include "utils/channel.hpp"
#include "common.h"

#include "nvbit_reg_rw.h"

extern "C" __device__ __noinline__ void instrument_inst(int pred, int pc, int opcode_id, int is_mem_inst, uint64_t addr1, int mref_id, uint64_t addr2,
                                                        int dst_oprnd, int dst_oprnd_type, int src_oprnd1, int src_oprnd1_type,
                                                        int src_oprnd2, int src_oprnd2_type, int src_oprnd3, int src_oprnd3_type,
                                                        int src_oprnd4, int src_oprnd4_type, int src_oprnd5, int src_oprnd5_type,
                                                        int pred_num, int isPredNeg, int isPredUniform, uint64_t pchannel_dev) {
        
    inst_access_t ia;

    /* TODO: some instructions about using %clock64 */
    uint64_t current_clk;                                   // yangjianchao16 add
    asm("mov.u64 %0, %clock64;" : "=l"(current_clk));       // yangjianchao16 add
    ia.curr_clk = current_clk;                              // yangjianchao16 add
    
    if (!pred) {
        ia.pred_inst  = 1;
    }else{
        ia.pred_inst  = 0;
    }
    ia.pred_num = pred_num;

    ia.sm_id = get_smid();
    int4 cta = get_ctaid();
    ia.cta_id_x = cta.x;
    ia.cta_id_y = cta.y;
    ia.cta_id_z = cta.z;
    /* warp id within a thread block. */
    ia.warp_id = get_warpid();
    /* global warp id within all thread blocks of one kernel. */
    ia.gwarp_id = get_global_warp_id();
    ia.opcode_id = opcode_id;
    ia.pc = pc;
    ia.is_mem_inst = is_mem_inst;
    ia.mref_id = mref_id;
    ia.isPredNeg = isPredNeg;
    ia.isPredUniform = isPredUniform;

    // ia.pred_reg_value = nvbit_read_pred_reg();

    const uint32_t active_mask = __ballot_sync(__activemask(), 1);
    const int laneid = get_laneid();
    const int first_laneid = __ffs(active_mask) - 1;
    const uint32_t predicate_mask = __ballot_sync(__activemask(), pred);
    const int active_threads = __popc(active_mask);

    /* active threads that are not predicated off per instruction executed */
    ia.pred_active_threads = active_threads - __popc(predicate_mask);

    if (is_mem_inst){
        /* collect memory address information from other threads */
        for (int i = 0; i < 32; i++) {
            ia.mem_addrs1[i] = __shfl_sync(active_mask, addr1, i);
            if(mref_id == 2)
                ia.mem_addrs2[i] = __shfl_sync(active_mask, addr2, i);
        }
    }

    /* Judge if the addr is strid-mode or delta-mode. START */
    bool const_stride = true;
    bool first_bit1_found = false;
    bool last_bit1_found = false;

    



    /* Judge if the addr is strid-mode or delta-mode. END */

    
    ia.dst_oprnd = dst_oprnd;
    ia.dst_oprnd_type = dst_oprnd_type;

    ia.active_mask = active_mask;
    ia.predicate_mask = predicate_mask;

    ia.src_oprnds[0] = src_oprnd1;
    ia.src_oprnds_type[0] = src_oprnd1_type;
    ia.src_oprnds[1] = src_oprnd2;
    ia.src_oprnds_type[1] = src_oprnd2_type;
    ia.src_oprnds[2] = src_oprnd3;
    ia.src_oprnds_type[2] = src_oprnd3_type;
    ia.src_oprnds[3] = src_oprnd4;
    ia.src_oprnds_type[3] = src_oprnd4_type;
    ia.src_oprnds[4] = src_oprnd5;
    ia.src_oprnds_type[4] = src_oprnd5_type;


    /* first active lane pushes information on the channel */
    if (first_laneid == laneid) {
        ChannelDev *channel_dev = (ChannelDev *)pchannel_dev;
        channel_dev->push(&ia, sizeof(inst_access_t));
    }
}