--  tool_flow.adb
--  SPARK implementation of FLOW (0x03) — DMA transfer.
--  Initiates a DMA transfer from NVMe SSD to GPU VRAM.
--  Verified: size > 0, size ≤ aperture, DMA capable, no overflow.

with Interfaces;
with Interfaces.C.Strings;

package body Tool_Flow with SPARK_Mode
is

   use type Interfaces.Unsigned_64;
   use type Interfaces.Unsigned_32;

     function Validate
       (Vial : not null access constant Vial_Constraints;
        Op   : not null access constant Drop_Type) return Interfaces.C.int
    is
    begin
       if Op.Size = 0 then
          return 0;
       end if;

       if Interfaces.Unsigned_64(Op.Size) > Vial.Aperture_Max then
          return 0;
       end if;

       if not Vial.DMA_Capable then
          return 0;
       end if;

       if Op.Src_Addr + Interfaces.Unsigned_64(Op.Size) < Op.Src_Addr then
          return 0;
       end if;

       if Op.Dst_Addr + Interfaces.Unsigned_64(Op.Size) < Op.Dst_Addr then
          return 0;
       end if;

       return 1;
    end Validate;

     function Execute
       (Vial : not null access constant Vial_Constraints;
        Op   : not null access constant Drop_Type) return Tool_Result
    is
       Transfer_Size : constant Interfaces.Unsigned_64 :=
         Interfaces.Unsigned_64(Op.Size);
    begin
       pragma Assert (Op.Size > 0);
       pragma Assert (Interfaces.Unsigned_64(Op.Size) <= Vial.Aperture_Max);
       pragma Assert (Vial.DMA_Capable);

       return (Success            => True,
               Cycles_Spent       => Transfer_Size / 1024,
               Bytes_Transferred  => Transfer_Size,
               Error_Message      => Interfaces.C.Strings.Null_Ptr);
    end Execute;

end Tool_Flow;
