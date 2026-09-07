unit HASH_SHA256;

interface
uses Classes, SysUtils, DCPcrypt2, DCPsha256;
function FileSHA256(const FileName: string): string;
implementation
function FileSHA256(const FileName: string): string;
var
  Hash: TDCP_sha256;
  FS: TFileStream;
  Buffer: array[0..65535] of Byte;
  BytesRead: Integer;
  Digest: array[0..31] of Byte;
  i: Integer;
begin
  Result := '';
  if not FileExists(FileName) then
    Exit;

  Hash := TDCP_sha256.Create(nil);
  try
    Hash.Init;
    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      repeat
        BytesRead := FS.Read(Buffer[0], SizeOf(Buffer));
        if BytesRead > 0 then
          Hash.Update(Buffer[0], BytesRead);
      until BytesRead = 0;
    finally
      FS.Free;
    end;
    Hash.Final(Digest[0]);
    for i := 0 to 31 do
      Result := Result + IntToHex(Digest[i], 2);
    Result := LowerCase(Result);
  finally
    Hash.Free;
  end;
end;
end.
