# Kế hoạch MVP — 7 ngày

Mục tiêu: nhóm 2–4 người chơi được qua Radmin VPN, voice qua Discord. Hình khối, chưa cần đẹp.

## Phạm vi MVP

- Map khối hộp, khoảng 12–20 phòng, 2 tầng.
- Người chơi góc nhìn thứ nhất: đi, chạy, ngồi, đèn pin, mở cửa, nhặt/thả đồ.
- Vòng chơi: vào tòa nhà → nhặt đồ → mang ra xe trước khi hết giờ → đạt chỉ tiêu hay không → chơi lại.
- Một quái: **ma-nơ-canh** — chỉ di chuyển khi không người chơi nào nhìn thấy nó; chạm vào là chết.
- Chết → chế độ xem người còn sống.
- Menu: Host / Join bằng IP / Settings (ngôn ngữ en/vi, độ nhạy chuột, âm lượng) / Quit.
- Xuất được file `.exe` cho Windows.

**Không có trong MVP:** voice trong game, Steam, procedural map, quái thứ hai, cửa hàng, tiến trình, asset thật.

## Lộ trình

| Ngày | Việc | Xong khi |
|---|---|---|
| 1 | Quy ước, project, Git, i18n, điều khiển người chơi, đèn pin, cửa, nhặt đồ, map khối hộp | Chơi một mình đi lại, mở cửa, nhặt đồ được |
| 2 | Menu Host/Join bằng IP, spawn người chơi, đồng bộ chuyển động | 2 instance trên một máy thấy nhau di chuyển |
| 3 | Đồ vật và cửa do host quyết định | 2 người cùng nhặt 1 món: chỉ 1 người lấy được. Thử qua Radmin với 1 bạn |
| 4 | Vòng chơi: đồng hồ, chỉ tiêu, xe, màn kết quả, chơi lại; nút chọn ngôn ngữ | Chơi trọn 1 vòng |
| 5 | Quái ma-nơ-canh, cái chết, chế độ xem | Quái giết được người, vòng kết thúc đúng |
| 6 | Âm thanh, đèn chập chờn, không khí | Chơi thử 3–4 người qua Radmin |
| 7 | Sửa lỗi, export `.exe` | Bạn bè chạy được bản build |

Nếu trễ: bỏ bớt phần âm thanh (ngày 6), **không bỏ buổi chơi thử**.

## Checklist chơi thử mỗi lần

- [ ] Host và 1–3 client vào được cùng trận
- [ ] Mọi người thấy nhau di chuyển mượt
- [ ] Nhặt/thả đồ không bị nhân đôi, không mất đồ
- [ ] Cửa đóng/mở giống nhau trên mọi máy
- [ ] Hết giờ / đủ chỉ tiêu: kết quả giống nhau trên mọi máy
- [ ] Chạy game ở `en` và `vi`: không sót khóa dịch, chữ không tràn khung
- [ ] Ghi lại: lúc nào cả nhóm hét / cười, lúc nào chán
