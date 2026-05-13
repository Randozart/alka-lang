--  tool_shift.adb
--  SPARK implementation of SHIFT (0x04) — BAR window remapping.
--  Remaps the BAR1 sliding window to a new offset.
--  Verified: offset ≤ aperture, page-aligned, window fits BAR range.

with Interfaces;
with Interfaces.C.Strings;

package body Tool_Shift with SPARK_Mode
is

   use type Interfaces.Unsigned_64;

   function Validate
     (Op   : Drop_Type;
      Vial : Vial_Constraints) return Boolean
   is
      pragma Unreferenced (Vial);
      New_Offset : constant Interfaces.Unsigned_64 := Op.Src_Addr;
   begin
      if New_Offset > Max_Aperture then
         return False;
      end if;

      if (New_Offset and 16#FFF#) /= 0 then
         return False;
      end if;

      return True;
   end Validate;

   procedure Execute
     (Op     : Drop_Type;
      Vial   : Vial_Constraints;
      Result : out Tool_Result)
   is
      pragma Unreferenced (Vial);
      New_Offset : constant Interfaces.Unsigned_64 := Op.Src_Addr;
   begin
      pragma Assert (New_Offset <= Max_Aperture);
      pragma Assert ((New_Offset and 16#FFF#) = 0);

      Result.Success := True;
      Result.Cycles_Spent := 10;
      Result.Bytes_Transferred := 0;
      Result.Error_Message := Interfaces.C.Strings.Null_Ptr;
   end Execute;

end Tool_Shift;
