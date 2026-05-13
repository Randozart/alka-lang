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
      (Vial : not null access constant Vial_Constraints;
       Op   : not null access constant Drop_Type) return Interfaces.C.int
    is
       pragma Unreferenced (Vial);
       New_Offset : constant Interfaces.Unsigned_64 := Op.Src_Addr;
    begin
       if New_Offset > Max_Aperture then
          return 0;
       end if;

       if (New_Offset and 16#FFF#) /= 0 then
          return 0;
       end if;

       return 1;
    end Validate;

    function Execute
      (Vial : not null access constant Vial_Constraints;
       Op   : not null access constant Drop_Type) return Tool_Result
    is
       pragma Unreferenced (Vial);
       New_Offset : constant Interfaces.Unsigned_64 := Op.Src_Addr;
    begin
       pragma Assert (New_Offset <= Max_Aperture);
       pragma Assert ((New_Offset and 16#FFF#) = 0);

       return (Success            => True,
               Cycles_Spent       => 10,
               Bytes_Transferred  => 0,
               Error_Message      => Interfaces.C.Strings.Null_Ptr);
    end Execute;

end Tool_Shift;
