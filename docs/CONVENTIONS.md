# Quy ước dự án — áp dụng cho MỌI AI agent và người viết code

Tên tạm của game: **Night Shift / Ca Trực Đêm** — game kinh dị co-op 3D, 2–4 người, PC Windows.
Kế hoạch MVP: xem `docs/MVP_PLAN.md`.

Đọc hết file này trước khi viết code. Nếu yêu cầu của người dùng mâu thuẫn với file này, hỏi lại người dùng.

---

## 1. Công nghệ (không tự ý đổi)

| Hạng mục | Giá trị |
|---|---|
| Engine | **Godot 4.7 stable**, bản thường (KHÔNG phải bản .NET) |
| Đường dẫn Godot | `D:\GoDot\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe` (lệnh `godot` cũng trỏ tới bản này) |
| Ngôn ngữ | **Typed GDScript** duy nhất. Không C#, không GDExtension tự viết |
| Renderer | Forward+ |
| Mạng | High-level multiplayer của Godot, `ENetMultiplayerPeer`, cổng UDP mặc định `7777` |
| Chơi qua Internet (MVP) | Radmin VPN: host đưa IP 26.x.x.x, client nhập IP. Không có Steam trong MVP |
| Voice (MVP) | Discord, ngoài game. Chưa làm voice trong game |

### Cấm dùng API/cú pháp Godot 3
Đây là lỗi AI hay mắc nhất. Không dùng:

| Sai (Godot 3) | Đúng (Godot 4) |
|---|---|
| `KinematicBody`, `Spatial` | `CharacterBody3D`, `Node3D` |
| `move_and_slide(velocity, Vector3.UP)` | gán `velocity` rồi gọi `move_and_slide()` |
| `yield(...)` | `await ...` |
| `export var`, `onready var` | `@export var`, `@onready var` |
| `connect("signal", self, "_method")` | `signal_name.connect(_method)` |
| `remote`, `master`, `puppet`, `rset` | `@rpc(...)`, `MultiplayerSynchronizer` |
| `get_tree().network_peer` | `multiplayer.multiplayer_peer` |
| `instance()` | `instantiate()` |
| `PoolStringArray`, `deg2rad` | `PackedStringArray`, `deg_to_rad` |

Nếu không chắc một API có trong 4.7, tra tài liệu `https://docs.godotengine.org/en/stable/` thay vì đoán.

---

## 2. Cấu trúc thư mục

Gom theo tính năng: scene `.tscn` và script `.gd` của cùng một thứ nằm chung thư mục.

```
res://
  core/            Autoload và hằng số dùng toàn game (Settings, GameConfig, Net...)
  features/
    interaction/   Interactable: thành phần gắn vào thứ người chơi bấm E được
    player/        player.tscn, player.gd, flashlight...
    items/         đồ nhặt được
    doors/
    monster/
    round/         đồng hồ, chỉ tiêu, xe, kết quả vòng
  levels/
    greybox_01/    map dựng bằng khối hộp
  ui/
    main_menu/
    hud/
    settings/
  i18n/            translations.csv + font
  assets/          asset bên thứ ba (models, audio, fonts) — phải có trong CREDITS.md
  tests/           scene kiểm tra tự động chạy headless
  docs/
```

Không tạo thư mục gốc mới ngoài danh sách trên khi chưa hỏi người dùng.

---

## 3. Viết GDScript

Theo GDScript style guide chính thức. Các điểm bắt buộc:

- **Mọi biến, tham số, giá trị trả về đều có kiểu.** `var speed: float = 5.0`, `func get_items() -> Array[Item]:`. Dùng `:=` khi kiểu đã rõ từ vế phải.
- Project bật cảnh báo kiểu ở mức **error** (`untyped_declaration`, `unsafe_*`). Không tắt cảnh báo để code chạy được.
- Tên:
  - file và thư mục: `snake_case` (`player_controller.gd`)
  - `class_name`: `PascalCase`
  - node trong scene: `PascalCase`
  - hàm và biến: `snake_case`; hàm/biến nội bộ bắt đầu bằng `_`
  - hằng số và enum value: `UPPER_SNAKE_CASE`
  - signal: thì quá khứ (`item_picked_up`, `round_ended`)
- Thứ tự trong file: `class_name` → `extends` → signals → enums → constants → `@export` → biến → `@onready` → `_ready`/`_process`... → hàm public → hàm `_private`.
- Lấy node bằng `@onready var x: Node3D = $Path` hoặc `%UniqueName`. Không `get_node()` rải rác trong `_process`.
- Logic vật lý và chuyển động trong `_physics_process`, không trong `_process`.
- Ưu tiên signal để báo lên trên; gọi hàm để ra lệnh xuống dưới. Con không biết cha là ai.
- Số "ma thuật" (tốc độ, thời gian, khoảng cách) đặt thành `@export` hoặc hằng số có tên.
- Comment bằng tiếng Anh, ngắn, giải thích **vì sao**, không nhắc lại code làm gì.
- Hàm dài quá ~40 dòng thì tách.

---

## 4. Multiplayer — quy tắc quan trọng nhất

**Host (peer id `1`) là nguồn sự thật duy nhất.** Host cũng là một người chơi (listen server).

| Host quyết định | Client tự quyết |
|---|---|
| Nhặt/thả/vị trí đồ vật | Chuyển động và hướng nhìn của chính mình |
| Cửa, điện, đèn | Bật/tắt đèn pin và ngồi (đồng bộ qua `MultiplayerSynchronizer` của người chơi) |
| Máu, cái chết | Camera, UI, âm thanh cục bộ |
| Quái: AI, vị trí, ai đang nhìn nó | |
| Đồng hồ, chỉ tiêu, kết quả vòng | |

Mẫu bắt buộc:

1. Client **yêu cầu**: `@rpc("any_peer", "call_local", "reliable")` gửi tới host bằng `rpc_id(1, ...)`.
2. Host **kiểm tra** (`multiplayer.is_server()`), dùng `multiplayer.get_remote_sender_id()` để biết ai gửi, từ chối nếu không hợp lệ (quá xa, đồ đã có người cầm, người đã chết...).
3. Host **phát kết quả**: `@rpc("authority", "call_local", "reliable")` tới mọi người.

### Số người chơi (luật cứng)
- **Tối thiểu 2, tối đa 4**, tính cả host. Dùng `GameConfig.MIN_PLAYERS` / `GameConfig.MAX_PLAYERS` trong `core/game_config.gd`; không viết số 2 hay 4 ở chỗ khác.
- Tạo server với `max_clients = GameConfig.MAX_PLAYERS` (dư 1 chỗ so với số client thật): người thừa vẫn kết nối được để host gửi lý do `ERR_ROOM_FULL` rồi ngắt sau `Net.KICK_DELAY_SEC`. Nếu để ENet tự từ chối, người thừa chỉ thấy kết nối bị treo đến khi hết thời gian chờ. Việc nhận/từ chối nằm trong `core/net.gd` (`_admission_problem`).
- Host chỉ bắt đầu vòng chơi khi số người >= `MIN_PLAYERS`. Không thêm chế độ chơi một mình hay cờ bỏ qua luật này.

Thêm:
- Node người chơi tên là chính peer id (`str(peer_id)`), authority của node đó (chỉ phần chuyển động) là peer id đó.
- Spawn người chơi và đồ vật bằng `MultiplayerSpawner`. Đồng bộ vị trí liên tục bằng `MultiplayerSynchronizer`, không tự gửi RPC mỗi frame.
- Dữ liệu tần suất cao (vị trí) dùng `unreliable` / `unreliable_ordered`. Sự kiện (nhặt đồ, chết, kết thúc vòng) dùng `reliable`.
- Không gửi `Object`/`Node` qua RPC; gửi id, `NodePath` hoặc giá trị đơn giản.
- Code chỉ host được chạy phải có guard `if not multiplayer.is_server(): return` ở đầu.
- Mọi tính năng mạng phải thử với **ít nhất 2 instance** (Debug → Customize Run Instances) trước khi báo xong.

---

## 5. Đa ngôn ngữ (English + Tiếng Việt)

- **Ngôn ngữ mặc định: tiếng Anh (`en`)**, kể cả khi Windows đang để tiếng Việt. Người chơi đổi sang `vi` trong Settings. Fallback: `en`.
- **Không bao giờ viết chữ người chơi nhìn thấy trực tiếp** vào code hay scene. Dùng khóa dịch:
  - trong scene: đặt `text` của Label/Button là khóa (ví dụ `UI_HOST`), Godot tự dịch.
  - trong code: `tr("UI_HOST")`.
- Khóa viết `UPPER_SNAKE_CASE` có tiền tố: `UI_` (menu), `HUD_`, `ITEM_`, `ROUND_`, `MSG_` (thông báo), `SET_` (settings), `ERR_`.
- Tất cả bản dịch nằm trong **một file** `res://i18n/translations.csv`, cột: `keys,en,vi`. Mỗi khóa mới phải có đủ cả `en` và `vi` trong cùng thay đổi.
- Chuỗi có biến dùng placeholder có tên, không nối chuỗi:
  `tr("HUD_QUOTA").format({"current": 120, "target": 300})` với bản dịch `Quota: {current}/{target}`.
- Ngôn ngữ đã chọn lưu trong `user://settings.cfg`.
- Font dùng chung phải hiển thị đủ dấu tiếng Việt; đặt trong `res://i18n/` và ghi vào `CREDITS.md`.
- Không dịch: tên người chơi, địa chỉ IP, tên file.
- UI phải chịu được chữ tiếng Việt dài hơn tiếng Anh ~30% (dùng container, không đặt kích thước cứng cho Label).

---

## 6. Asset và giấy phép

- Chỉ dùng asset có giấy phép đã kiểm tra (ưu tiên CC0). "Miễn phí" không có nghĩa là được dùng.
- Mỗi asset bên thứ ba phải có một dòng trong `CREDITS.md`: tên, tác giả, link, giấy phép.
- Không tự tải hay thêm asset, addon, plugin. Đề xuất cho người dùng trước.
- MVP dùng hình khối (CSG / MeshInstance3D primitive). Không cần Blender.

---

## 7. Cách AI làm việc trong repo này

- **Không cài, tải, nâng cấp phần mềm, addon, plugin hay package** khi chưa được người dùng đồng ý rõ ràng.
- Không sửa PATH, registry, firewall hay thiết lập hệ thống.
- **Không commit, không push** trừ khi người dùng yêu cầu. Khi được yêu cầu: tác giả là người dùng (`hieutrungg`), **không thêm dòng `Co-Authored-By` hay ghi công AI** vào commit/PR.
- Mỗi task một nhánh Git (`feat/...`, `fix/...`). Hai agent không sửa cùng một file cùng lúc.
- Chỉ sửa file liên quan đến task. Muốn đổi `project.godot`, file quy ước này hoặc kiến trúc mạng thì nói rõ trong báo cáo.
- Thay đổi nhỏ, mỗi lần một bước chạy thử được.
- Kiểm tra trước khi báo xong:
  1. Import và tìm lỗi script:
     `godot --headless --path . --import`
  2. Kiểm tra cú pháp một script:
     `godot --headless --path . --check-only --script res://duong/dan/file.gd`
  3. Chạy các scene kiểm tra trong `tests/` (in `PASS`/`FAIL`, thoát với mã 0 nếu đạt):
     `godot --headless --path . res://tests/smoke_day1.tscn`
     Thay đổi về mạng thì chạy thêm bài test nhiều tiến trình (1 host, 3 client, 1 người thừa):
     `powershell -ExecutionPolicy Bypass -File tests/run_net_smoke.ps1`
  4. Nói rõ người dùng cần chạy thử gì trong editor (bao nhiêu instance, bấm gì, kết quả mong đợi).
- Báo cáo cho người dùng bằng **tiếng Việt**: đã làm gì, file nào, đã kiểm tra gì, chưa kiểm tra gì.
- Không nói "đã chạy được" nếu chưa thực sự chạy.
