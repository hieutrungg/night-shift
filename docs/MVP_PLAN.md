# Kế hoạch MVP — 7 ngày

Mục tiêu: nhóm 2–4 người chơi được qua Radmin VPN, voice qua Discord. Hình khối, chưa cần đẹp.

## Số người chơi — luật cứng (online)

- **Chơi online: tối thiểu 2, tối đa 4 người** (tính cả host). Không có ngoại lệ hay cờ bỏ qua luật này.
- **Chế độ chơi một mình** (thêm sau ngày 7, theo yêu cầu): chế độ riêng, offline hoàn toàn, có nút riêng ở menu. Chỉ tiêu thấp hơn, ma-nơ-canh chậm hơn và ngủ lâu hơn đầu vòng; Esc tạm dừng game. Không ảnh hưởng luật 2–4 người của chế độ online.
- Host không bắt đầu vòng chơi được khi chưa đủ 2 người.
- Người thứ 5 kết nối vào sẽ bị từ chối kèm thông báo "phòng đã đầy".
- Hai con số này chỉ được khai báo ở một chỗ: `core/game_config.gd` (`MIN_PLAYERS`, `MAX_PLAYERS`).
- Ngày 1 chưa có mạng nên bản thử chạy một người chỉ để kiểm tra điều khiển; luật 2–4 người bắt đầu áp dụng từ ngày 2.

## Phạm vi MVP

- Map khối hộp, khoảng 12–20 phòng, 2 tầng.
- Người chơi góc nhìn thứ nhất: đi, chạy, ngồi, đèn pin, mở cửa, nhặt/thả đồ.
- Vòng chơi: xe đưa đội đến → xuống xe → nhặt đồ → đạt chỉ tiêu → cả đội lên xe hoặc tài xế giữ G để rời đi; hết giờ xe vẫn rời đi. Trên xe an toàn khỏi ma-nơ-canh, người bị bỏ lại tính là chết → kết quả → chơi lại.
- Một loại quái: **ma-nơ-canh**. Số con theo số người (1 người: 1, 2–3 người: 2, 4 người: 3), thức dậy lần lượt; con ở phòng trưng bày được tráo ngẫu nhiên với một con giả mỗi vòng. Nó chỉ đứng yên khi người còn sống nhìn thấy phần cơ thể được đèn pin hoặc đèn trần chiếu sáng; giết trong tầm 1,2 m kể cả khi đứng yên, có kiểm tra tường/cửa chắn. Nhạc truy đuổi bắt đầu khi nó di chuyển, càng gần càng rõ và phát thêm 2 giây sau khi nó dừng.
- Chết → chế độ xem người còn sống.
- Menu: Host / Join bằng IP / Settings (ngôn ngữ en/vi, độ nhạy chuột, âm lượng) / Quit.
- Xuất được file `.exe` cho Windows.

**Không có trong MVP:** voice trong game, Steam, procedural map, quái thứ hai, cửa hàng, tiến trình, asset thật.

## Lộ trình

| Ngày | Việc | Xong khi |
|---|---|---|
| 1 | Quy ước, project, Git, i18n, điều khiển người chơi, đèn pin, cửa, nhặt đồ, map khối hộp | Chơi một mình đi lại, mở cửa, nhặt đồ được |
| 2 | Menu Host/Join bằng IP, phòng chờ (lobby), spawn người chơi, đồng bộ chuyển động | 2 instance trên một máy thấy nhau di chuyển. Instance thứ 5 bị từ chối. Host không bấm Start được khi chỉ có 1 người |
| 3 | Đồ vật và cửa do host quyết định | 2 người cùng nhặt 1 món: chỉ 1 người lấy được. Thử qua Radmin với 1 bạn |
| 4 | Vòng chơi: đồng hồ, chỉ tiêu, xe, màn kết quả, chơi lại; nút chọn ngôn ngữ | Chơi trọn 1 vòng |
| 5 | Quái ma-nơ-canh, cái chết, chế độ xem | Quái giết được người, vòng kết thúc đúng |
| 6 | Âm thanh, đèn chập chờn, không khí | Chơi thử 3–4 người qua Radmin |
| 7 | Sửa lỗi, export `.exe` | Bạn bè chạy được bản build |

Nếu trễ: bỏ bớt phần âm thanh (ngày 6), **không bỏ buổi chơi thử**.

## Trạng thái (cập nhật sau ngày 7)

- Ngày 1–7: đã làm xong phần code, test tự động đạt (1 người: `tests/smoke_day1.tscn`; mạng 5 tiến trình: `tests/run_net_smoke.ps1`).
- Đã có bản build Windows: `tests/export_build.ps1` → `build/NightShift.zip`.
- **Chưa làm:** buổi chơi thử thật 3–4 người qua Radmin (mục tiêu ngày 6–7). Ghi kết quả vào checklist dưới đây.

## Checklist chơi thử mỗi lần

- [ ] Host và 1–3 client vào được cùng trận
- [ ] Người thứ 5 bị từ chối; 1 người không bắt đầu được vòng chơi
- [ ] Mọi người thấy nhau di chuyển mượt
- [ ] Nhặt/thả đồ không bị nhân đôi, không mất đồ
- [ ] Cửa đóng/mở giống nhau trên mọi máy
- [ ] Hết giờ / đủ chỉ tiêu: kết quả giống nhau trên mọi máy
- [ ] Chạy game ở `en` và `vi`: không sót khóa dịch, chữ không tràn khung
- [ ] Ghi lại: lúc nào cả nhóm hét / cười, lúc nào chán
