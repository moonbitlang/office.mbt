///|
let ole_identifier : Array[Byte] = [
  0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1,
].map(v => v.to_byte())

///|
let header_cls_id : Bytes = Bytes::make(16, (0).to_byte())

///|
let end_of_chain = -2

///|
let free_sector = -1

///|
let fat_sector = -3

///|
let dif_sector = -4

///|
fn read_u16_le(bytes : BytesView, offset : Int) -> Int raise XlsxError {
  if offset < 0 || offset + 2 > bytes.length() {
    raise InvalidEncryptionInfo(msg="cfb read out of bounds")
  }
  let b0 = bytes[offset].to_int()
  let b1 = bytes[offset + 1].to_int()
  b0 | (b1 << 8)
}

///|
fn read_u32_le(bytes : BytesView, offset : Int) -> UInt raise XlsxError {
  if offset < 0 || offset + 4 > bytes.length() {
    raise InvalidEncryptionInfo(msg="cfb read out of bounds")
  }
  @crypto.u32_from_le(bytes, offset)
}

///|
fn read_i32_le(bytes : BytesView, offset : Int) -> Int raise XlsxError {
  let value = read_u32_le(bytes, offset)
  let signed = value.reinterpret_as_int()
  signed
}

///|
fn read_u64_le(bytes : BytesView, offset : Int) -> UInt64 raise XlsxError {
  if offset < 0 || offset + 8 > bytes.length() {
    raise InvalidEncryptionInfo(msg="cfb read out of bounds")
  }
  @crypto.u64_from_le(bytes, offset)
}

///|
priv struct CfbSector {
  mut cls_id : Bytes
  content : Bytes
  mut name : String
  mut c : Int
  mut l : Int
  mut r : Int
  mut color : Int
  mut size : Int
  mut start : Int
  state : Int
  mut type_id : Int
}

///|
priv struct CfbBuilder {
  mut stream : Array[Byte]
  mut position : Int
  mut paths : Array[String]
  mut sectors : Array[CfbSector]
}

///|
fn cfb_builder_new() -> CfbBuilder {
  {
    stream: [],
    position: 0,
    paths: ["Root Entry/"],
    sectors: [
      {
        cls_id: header_cls_id,
        content: Bytes::default(),
        name: "Root Entry",
        c: -1,
        l: -1,
        r: -1,
        color: 1,
        size: 0,
        start: 0,
        state: 0,
        type_id: 5,
      },
    ],
  }
}

///|
fn CfbBuilder::write_bytes(self : CfbBuilder, value : BytesView) -> Unit {
  let pos = self.position
  let needed = pos + value.length()
  if self.stream.length() < needed {
    self.stream.resize(needed, (0).to_byte())
  }
  for i in 0..<value.length() {
    self.stream[pos + i] = value[i]
  }
  self.position = needed
}

///|
fn CfbBuilder::write_uint16(self : CfbBuilder, value : Int) -> Unit {
  self.write_bytes([(value & 0xff).to_byte(), ((value >> 8) & 0xff).to_byte()])
}

///|
fn CfbBuilder::write_uint32(self : CfbBuilder, value : Int) -> Unit {
  self.write_bytes([
    (value & 0xff).to_byte(),
    ((value >> 8) & 0xff).to_byte(),
    ((value >> 16) & 0xff).to_byte(),
    ((value >> 24) & 0xff).to_byte(),
  ])
}

///|
fn CfbBuilder::write_uint64(self : CfbBuilder, value : Int) -> Unit {
  let lo = value & 0xffff_ffff
  let hi = (value >> 32) & 0xffff_ffff
  self.write_uint32(lo)
  self.write_uint32(hi)
}

///|
fn CfbBuilder::write_utf16le(self : CfbBuilder, value : StringView) -> Unit {
  let bytes = @encoding/utf16.encode(value, bom=false, endianness=Little)
  self.write_bytes(bytes)
}

///|
fn CfbBuilder::put(self : CfbBuilder, name : String, content : Bytes) -> Unit {
  let root = self.paths[0]
  let mut path = if root.length() <= name.length() && name.has_prefix(root) {
    name
  } else if root.length() > 0 && !root.has_suffix("/") {
    root + "/" + name
  } else {
    root + name
  }
  path = path.replace_all(old="//", new="/")
  let sector : CfbSector = {
    cls_id: header_cls_id,
    content,
    name: path,
    c: -1,
    l: -1,
    r: -1,
    color: 1,
    size: content.length(),
    start: 0,
    state: 0,
    type_id: 2,
  }
  self.sectors.push(sector)
  self.paths.push(path)
}

///|
fn cfb_compare(left : String, right : String) -> Int {
  let left_parts = Array::from_iter(left.split("/"))
  let right_parts = Array::from_iter(right.split("/"))
  let left_len = left_parts.length()
  let right_len = right_parts.length()
  let limit = if left_len < right_len { left_len } else { right_len }
  for i in 0..<limit {
    let l = left_parts[i]
    let r = right_parts[i]
    let j = l.length() - r.length()
    if j != 0 {
      return j
    }
    if l != r {
      return if l < r { -1 } else { 1 }
    }
  }
  left_parts.length() - right_parts.length()
}

///|
fn parent_path(path : String) -> String {
  match path.rev_find("/") {
    Some(pos) => path[:pos].to_owned()
    None => ""
  }
}

///|
fn base_name(path : String) -> String {
  match path.rev_find("/") {
    Some(pos) => path[pos + 1:].to_owned()
    None => path
  }
}

///|
priv struct CfbBuildObj {
  path : String
  sector : CfbSector
}

///|
fn CfbBuilder::prepare(self : CfbBuilder) -> Unit {
  let objects : Array[CfbBuildObj] = []
  for i in 0..<self.paths.length() {
    if self.sectors[i].type_id == 0 {
      continue
    }
    objects.push({ path: self.paths[i], sector: self.sectors[i] })
  }
  objects.sort_by((a, b) => cfb_compare(a.path, b.path))
  self.paths = []
  self.sectors = []
  for obj in objects {
    self.paths.push(obj.path)
    self.sectors.push(obj.sector)
  }
  let len = self.sectors.length()
  for i in 0..<len {
    let path = self.paths[i]
    self.sectors[i].name = base_name(path)
    self.sectors[i].color = 1
    self.sectors[i].l = -1
    self.sectors[i].r = -1
    self.sectors[i].c = -1
    self.sectors[i].size = self.sectors[i].content.length()
    self.sectors[i].start = 0
    if self.sectors[i].cls_id.length() == 0 {
      self.sectors[i].cls_id = header_cls_id
    }
    if i == 0 {
      self.sectors[i].c = if len > 1 { 1 } else { -1 }
      self.sectors[i].size = 0
      self.sectors[i].type_id = 5
    } else {
      if i + 1 < len && parent_path(self.paths[i + 1]) == parent_path(path) {
        self.sectors[i].r = i + 1
      }
      self.sectors[i].type_id = 2
    }
  }
}

///|
fn CfbBuilder::locate(self : CfbBuilder) -> Array[Int] {
  let mut mini_stream_sector_size = 0
  let mut fat_sector_size = 0
  for sector in self.sectors {
    if sector.content.length() == 0 {
      continue
    }
    let size = sector.content.length()
    if size > 0 {
      if size < 0x1000 {
        mini_stream_sector_size += (size + 0x3f) >> 6
      } else {
        fat_sector_size += (size + 0x1ff) >> 9
      }
    }
  }
  let directory_sectors = (self.paths.length() + 3) >> 2
  let mini_stream_sectors = (mini_stream_sector_size + 7) >> 3
  let mini_fat_sectors = (mini_stream_sector_size + 0x7f) >> 7
  let sectors = mini_stream_sectors +
    fat_sector_size +
    directory_sectors +
    mini_fat_sectors
  let mut fat_sectors = (sectors + 0x7f) >> 7
  let mut difat_sectors = 0
  if fat_sectors > 109 {
    difat_sectors = (fat_sectors - 109 + 0x7e) >> 7
  }
  while (sectors + fat_sectors + difat_sectors + 0x7f) >> 7 > fat_sectors {
    fat_sectors = fat_sectors + 1
    difat_sectors = if fat_sectors <= 109 {
      0
    } else {
      (fat_sectors - 109 + 0x7e) >> 7
    }
  }
  let location : Array[Int] = [
    1, difat_sectors, fat_sectors, mini_fat_sectors, directory_sectors, fat_sector_size,
    mini_stream_sector_size, 0,
  ]
  self.sectors[0].size = mini_stream_sector_size << 6
  self.sectors[0].start = location[0] +
    location[1] +
    location[2] +
    location[3] +
    location[4] +
    location[5]
  location[7] = self.sectors[0].start + ((location[6] + 7) >> 3)
  location
}

///|
fn CfbBuilder::write_msat(self : CfbBuilder, location : Array[Int]) -> Unit {
  for i in 0..<109 {
    if i < location[2] {
      self.write_uint32(location[1] + i)
    } else {
      self.write_uint32(-1)
    }
  }
  let mut i = 109
  if location[1] != 0 {
    let mut offset = 0
    while offset < location[1] {
      while i < 236 + offset * 127 {
        if i < location[2] {
          self.write_uint32(location[1] + i)
        } else {
          self.write_uint32(-1)
        }
        i = i + 1
      }
      if offset == location[1] - 1 {
        self.write_uint32(end_of_chain)
      } else {
        self.write_uint32(offset + 1)
      }
      offset = offset + 1
    }
  }
}

///|
fn CfbBuilder::write_directory_entry(
  self : CfbBuilder,
  location : Array[Int],
) -> Unit {
  let mut i = 0
  while i < location[4] << 2 {
    let mut path = ""
    if i < self.paths.length() {
      path = self.paths[i]
    }
    if i >= self.paths.length() || path.length() == 0 {
      for _ in 0..<=16 {
        self.write_uint32(0)
      }
      for _ in 0..<=2 {
        self.write_uint32(-1)
      }
      for _ in 0..<=11 {
        self.write_uint32(0)
      }
      i = i + 1
      continue
    }
    if i == 0 {
      self.sectors[i].start = if self.sectors[i].size > 0 {
        self.sectors[i].start - 1
      } else {
        end_of_chain
      }
    }
    let name = self.sectors[i].name
    let sector_size = 2 * (name.length() + 1)
    self.write_utf16le(name)
    self.position = self.position + (64 - 2 * name.length())
    self.write_uint16(sector_size)
    self.write_bytes([self.sectors[i].type_id.to_byte()])
    self.write_bytes([self.sectors[i].color.to_byte()])
    self.write_uint32(self.sectors[i].l)
    self.write_uint32(self.sectors[i].r)
    self.write_uint32(self.sectors[i].c)
    if self.sectors[i].cls_id.length() == 0 {
      for _ in 0..<=3 {
        self.write_uint32(0)
      }
    } else {
      self.write_bytes(self.sectors[i].cls_id)
    }
    self.write_uint32(self.sectors[i].state)
    self.write_uint32(0)
    self.write_uint32(0)
    self.write_uint32(0)
    self.write_uint32(0)
    self.write_uint32(self.sectors[i].start)
    self.write_uint64(self.sectors[i].size)
    i = i + 1
  }
}

///|
fn cfb_write_chain(
  builder : CfbBuilder,
  head : Int,
  offset : Int,
  i : Int,
) -> (Int, Int) {
  let mut local_i = i
  let local_offset = offset + head
  while local_i < local_offset - 1 {
    builder.write_uint32(local_i + 1)
    local_i = local_i + 1
  }
  if head != 0 {
    local_i = local_i + 1
    builder.write_uint32(end_of_chain)
  }
  (local_offset, local_i)
}

///|
fn CfbBuilder::write_sector_chains(
  self : CfbBuilder,
  location : Array[Int],
) -> CfbSector {
  let mut i = 0
  let mut offset = 0
  while i < location[1] {
    self.write_uint32(dif_sector)
    i = i + 1
  }
  while i < location[1] + location[2] {
    self.write_uint32(fat_sector)
    i = i + 1
  }
  let (new_offset0, new_i0) = cfb_write_chain(
    self,
    location[3],
    offset + location[1] + location[2],
    i,
  )
  offset = new_offset0
  i = new_i0
  let (new_offset1, new_i1) = cfb_write_chain(self, location[4], offset, i)
  offset = new_offset1
  i = new_i1
  let mut sector = self.sectors[0]
  for idx in 0..<self.sectors.length() {
    sector = self.sectors[idx]
    if sector.content.length() == 0 {
      continue
    }
    let size = sector.content.length()
    if size < 0x1000 {
      continue
    }
    self.sectors[idx].start = offset
    let (new_offset2, new_i2) = cfb_write_chain(
      self,
      (size + 0x1ff) >> 9,
      offset,
      i,
    )
    offset = new_offset2
    i = new_i2
  }
  let (new_offset3, new_i3) = cfb_write_chain(
    self,
    (location[6] + 7) >> 3,
    offset,
    i,
  )
  offset = new_offset3
  i = new_i3
  while (self.position & 0x1ff) != 0 {
    self.write_uint32(end_of_chain)
  }
  i = 0
  offset = 0
  for idx in 0..<self.sectors.length() {
    sector = self.sectors[idx]
    if sector.content.length() == 0 {
      continue
    }
    let size = sector.content.length()
    if size == 0 || size >= 0x1000 {
      continue
    }
    self.sectors[idx].start = offset
    let (new_offset4, new_i4) = cfb_write_chain(
      self,
      (size + 0x3f) >> 6,
      offset,
      i,
    )
    offset = new_offset4
    i = new_i4
  }
  while (self.position & 0x1ff) != 0 {
    self.write_uint32(end_of_chain)
  }
  sector
}

///|
fn CfbBuilder::write(self : CfbBuilder) -> Bytes {
  self.prepare()
  let location = self.locate()
  self.stream = Array::make(location[7] << 9, (0).to_byte())
  for i in 0..<=7 {
    self.write_bytes([ole_identifier[i]])
  }
  self.write_bytes(Bytes::make(16, (0).to_byte()))
  self.write_uint16(0x003e)
  self.write_uint16(0x0003)
  self.write_uint16(0xfffe)
  self.write_uint16(0x0009)
  self.write_uint16(0x0006)
  self.write_bytes(Bytes::make(10, (0).to_byte()))
  self.write_uint32(location[2])
  self.write_uint32(location[0] + location[1] + location[2] + location[3] - 1)
  self.write_uint32(0)
  self.write_uint32(1 << 12)
  if location[3] != 0 {
    self.write_uint32(location[0] + location[1] + location[2] - 1)
  } else {
    self.write_uint32(end_of_chain)
  }
  self.write_uint32(location[3])
  if location[1] != 0 {
    self.write_uint32(location[0] - 1)
  } else {
    self.write_uint32(end_of_chain)
  }
  self.write_uint32(location[1])
  self.write_msat(location)
  let mut sector = self.write_sector_chains(location)
  self.write_directory_entry(location)
  for i in 1..<self.sectors.length() {
    sector = self.sectors[i]
    if sector.size >= 0x1000 {
      self.position = (sector.start + 1) << 9
      for b in sector.content {
        self.write_bytes([b])
      }
      while (sector.size & 0x1ff) != 0 && (self.position & 0x1ff) != 0 {
        self.write_bytes([(0).to_byte()])
      }
    }
  }
  for i in 1..<self.sectors.length() {
    sector = self.sectors[i]
    if sector.size > 0 && sector.size < 0x1000 {
      for b in sector.content {
        self.write_bytes([b])
      }
      while (self.position & 0x3f) != 0 {
        self.write_bytes([(0).to_byte()])
      }
    }
  }
  while self.position < self.stream.length() {
    self.write_bytes([(0).to_byte()])
  }
  Bytes::from_array(self.stream)
}

///|
priv struct CfbEntry {
  name : String
  type_id : Int
  start : Int
  size : Int
}

///|
priv struct CfbReader {
  bytes : Bytes
  sector_size : Int
  mini_sector_size : Int
  fat : Array[Int]
  mini_fat : Array[Int]
  entries : Array[CfbEntry]
  mini_stream : Bytes
}

///|
fn sector_offset(sector_size : Int, index : Int) -> Int {
  (index + 1) * sector_size
}

///|
fn read_sector_chain(
  fat : Array[Int],
  start : Int,
) -> Array[Int] raise XlsxError {
  let chain : Array[Int] = []
  let mut current = start
  let mut guard_count = 0
  while current != end_of_chain && current != free_sector {
    if current < 0 || current >= fat.length() {
      raise InvalidEncryptionInfo(msg="cfb chain out of bounds")
    }
    chain.push(current)
    let next = fat[current]
    if next == current {
      raise InvalidEncryptionInfo(msg="cfb chain cycle")
    }
    current = next
    guard_count = guard_count + 1
    if guard_count > fat.length() {
      raise InvalidEncryptionInfo(msg="cfb chain too long")
    }
  }
  chain
}

///|
fn cfb_read(bytes : BytesView) -> CfbReader raise XlsxError {
  if bytes.length() < 512 {
    raise InvalidEncryptionInfo(msg="cfb header too short")
  }
  for i in 0..<=7 {
    if bytes[i] != ole_identifier[i] {
      raise InvalidEncryptionInfo(msg="invalid cfb signature")
    }
  }
  let sector_shift = read_u16_le(bytes, 0x1e)
  let mini_sector_shift = read_u16_le(bytes, 0x20)
  let sector_size = 1 << sector_shift
  let mini_sector_size = 1 << mini_sector_shift
  let dir_start = read_i32_le(bytes, 0x30)
  let mini_fat_start = read_i32_le(bytes, 0x3c)
  let num_mini_fat = read_u32_le(bytes, 0x40).to_uint64().to_int()
  let difat_start = read_i32_le(bytes, 0x44)
  let num_difat = read_u32_le(bytes, 0x48).to_uint64().to_int()
  let fat_sectors : Array[Int] = []
  let mut pos = 0x4c
  for _ in 0..<=108 {
    let entry = read_i32_le(bytes, pos)
    if entry != free_sector {
      fat_sectors.push(entry)
    }
    pos = pos + 4
  }
  let mut difat_chain_start = difat_start
  let mut difat_count = 0
  while difat_chain_start != end_of_chain && difat_chain_start != free_sector {
    if difat_count >= num_difat {
      break
    }
    let offset = sector_offset(sector_size, difat_chain_start)
    let difat_bytes = bytes[offset:offset + sector_size]
    let mut idx = 0
    for _ in 0..<=126 {
      let entry = read_i32_le(difat_bytes, idx)
      if entry != free_sector {
        fat_sectors.push(entry)
      }
      idx = idx + 4
    }
    difat_chain_start = read_i32_le(difat_bytes, 127 * 4)
    difat_count = difat_count + 1
  }
  let fat : Array[Int] = []
  for sector in fat_sectors {
    let offset = sector_offset(sector_size, sector)
    let fat_bytes = bytes[offset:offset + sector_size]
    let mut idx = 0
    while idx < sector_size {
      fat.push(read_i32_le(fat_bytes, idx))
      idx = idx + 4
    }
  }
  let dir_chain = read_sector_chain(fat, dir_start)
  let dir_data : Array[Byte] = []
  for sector in dir_chain {
    let offset = sector_offset(sector_size, sector)
    let chunk = bytes[offset:offset + sector_size]
    dir_data.append(chunk.to_array())
  }
  let entries : Array[CfbEntry] = []
  let mut root_entry : CfbEntry = { name: "", type_id: 0, start: 0, size: 0 }
  let mut offset = 0
  while offset + 128 <= dir_data.length() {
    let entry_bytes = Bytes::from_array(dir_data[offset:offset + 128])
    let name_len = read_u16_le(entry_bytes, 0x40)
    let type_id = entry_bytes[0x42].to_int()
    let start = read_i32_le(entry_bytes, 0x74)
    let size = read_u64_le(entry_bytes, 0x78).to_int()
    let name = if name_len >= 2 {
      let name_bytes = entry_bytes[0:name_len - 2]
      @encoding/utf16.decode(name_bytes, ignore_bom=true, endianness=Little) catch {
        _ => raise InvalidEncryptionInfo(msg="invalid cfb name")
      }
    } else {
      ""
    }
    let entry = { name, type_id, start, size }
    if entries.length() == 0 {
      root_entry = entry
    }
    entries.push(entry)
    offset = offset + 128
  }
  let mini_fat : Array[Int] = []
  if num_mini_fat > 0 && mini_fat_start != end_of_chain {
    let mini_chain = read_sector_chain(fat, mini_fat_start)
    for sector in mini_chain {
      let offset = sector_offset(sector_size, sector)
      let chunk = bytes[offset:offset + sector_size]
      let mut idx = 0
      while idx < sector_size {
        mini_fat.push(read_i32_le(chunk, idx))
        idx = idx + 4
      }
    }
  }
  let mut mini_stream : Bytes = Bytes::default()
  if root_entry.size > 0 && root_entry.start != end_of_chain {
    let root_chain = read_sector_chain(fat, root_entry.start)
    let data : Array[Byte] = []
    for sector in root_chain {
      let offset = sector_offset(sector_size, sector)
      let chunk = bytes[offset:offset + sector_size]
      data.append(chunk.to_array())
    }
    if data.length() > root_entry.size {
      data.truncate(root_entry.size)
    }
    mini_stream = Bytes::from_array(data)
  }
  {
    bytes: Bytes::from_array(bytes.to_array()),
    sector_size,
    mini_sector_size,
    fat,
    mini_fat,
    entries,
    mini_stream,
  }
}

///|
fn CfbReader::read_stream(
  self : CfbReader,
  name : StringView,
) -> Bytes raise XlsxError {
  let mut entry : CfbEntry? = None
  let target = name.to_owned()
  for item in self.entries {
    if item.name == target {
      entry = Some(item)
      break
    }
  }
  match entry {
    None => raise InvalidEncryptionInfo(msg="cfb entry not found")
    Some(item) => {
      if item.type_id != 2 {
        raise InvalidEncryptionInfo(msg="cfb entry is not a stream")
      }
      if item.size == 0 {
        return Bytes::default()
      }
      if item.size < 0x1000 {
        if self.mini_stream.length() == 0 {
          raise InvalidEncryptionInfo(msg="cfb mini stream missing")
        }
        let data : Array[Byte] = []
        let mut current = item.start
        let mut remaining = item.size
        let mut guard_count = 0
        while current != end_of_chain && current != free_sector && remaining > 0 {
          let offset = current * self.mini_sector_size
          if offset + self.mini_sector_size > self.mini_stream.length() {
            raise InvalidEncryptionInfo(msg="cfb mini stream out of bounds")
          }
          let chunk = self.mini_stream[offset:offset + self.mini_sector_size]
          let take = if remaining < self.mini_sector_size {
            remaining
          } else {
            self.mini_sector_size
          }
          data.append(chunk[:take].to_array())
          remaining = remaining - take
          if current < 0 || current >= self.mini_fat.length() {
            raise InvalidEncryptionInfo(msg="cfb mini chain out of bounds")
          }
          current = self.mini_fat[current]
          guard_count = guard_count + 1
          if guard_count > self.mini_fat.length() {
            raise InvalidEncryptionInfo(msg="cfb mini chain too long")
          }
        }
        Bytes::from_array(data)
      } else {
        let chain = read_sector_chain(self.fat, item.start)
        let data : Array[Byte] = []
        for sector in chain {
          let offset = sector_offset(self.sector_size, sector)
          let chunk = self.bytes[offset:offset + self.sector_size]
          data.append(chunk.to_array())
        }
        if data.length() > item.size {
          data.truncate(item.size)
        }
        Bytes::from_array(data)
      }
    }
  }
}
