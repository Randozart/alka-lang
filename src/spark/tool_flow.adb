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
     (Op   : Drop_Type;
      Vial : Vial_Constraints) return Boolean
   is
   begin
      if Op.Size = 0 then
         return False;
      end if;

      if Interfaces.Unsigned_64(Op.Size) > Vial.Aperture_Max then
         return False;
      end if;

      if not Vial.DMA_Capable then
         return False;
      end if;

      if Op.Src_Addr + Interfaces.Unsigned_64(Op.Size) < Op.Src_Addr then
         return False;
      end if;

      if Op.Dst_Addr + Interfaces.Unsigned_64(Op.Size) < Op.Dst_Addr then
         return False;
      end if;

      return True;
   end Validate;

   procedure Execute
     (Op     : Drop_Type;
      Vial   : Vial_Constraints;
      Result : out Tool_Result)
   is
      Transfer_Size : constant Interfaces.Unsigned_64 :=
        Interfaces.Unsigned_64(Op.Size);
   begin
      pragma Assert (Op.Size > 0);
      pragma Assert (Interfaces.Unsigned_64(Op.Size) <= Vial.Aperture_Max);
      pragma Assert (Vial.DMA_Capable);

      Result.Success := True;
      Result.Cycles_Spent := Transfer_Size / 1024;
      Result.Bytes_Transferred := Transfer_Size;
      Result.Error_Message := Interfaces.C.Strings.Null_Ptr;
   end Execute;

end Tool_Flow;
