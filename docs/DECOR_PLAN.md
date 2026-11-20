# Kế hoạch decor map greybox_01

Mục tiêu: biến tòa nhà khối hộp thành **trụ sở bỏ hoang của một công ty may mặc**. Ma-nơ-canh có lý do để ở đây, mỗi phòng có một công dụng riêng, và người chơi nhận ra mình đang ở phòng nào.

Thứ tự làm (theo yêu cầu): **cửa → xe → nội thất từng phòng → đồ nhặt (sau cùng)**.

> **Trạng thái (cập nhật):** cửa, xe, nội thất 12 phòng + hành lang + bãi xe và **đồ nhặt đã xong**.
> Đồ nhặt: 7 loại dùng mô hình Kenney Furniture Kit (radio, đèn bàn, laptop, máy nướng bánh, máy xay, loa, chồng sách; $15–$80). Hộp đồ nghề và bình gốm bị bỏ vì không có mô hình. Đồ nhặt không bị làm xám mà phát sáng nhẹ để dễ thấy trong tối; khi cầm được thu nhỏ còn 70% để không che tầm nhìn.
> Khác so với kế hoạch: "Lotta tra Como" thực tế là **tủ ngăn kéo thấp** (2,06 × 0,87 m), không phải tủ cao, nên tủ cao trong phòng tủ đồ dùng `bookcaseClosedDoors` của Kenney. Old Door là một mesh liền (khung + cánh mở hé), được tách và xoay cánh về vị trí đóng bằng code (`features/doors/door_model.gd`). Đồ Kenney được làm xám/tối cho hợp không khí. Đo được ~270–290 FPS (1280×720, Radeon 880M), không cần cắt giảm.
> Dữ liệu đặt đồ: `levels/greybox_01/greybox_01_decor.gd`. Test tự động kiểm tra luật đặt đồ và đường đi tới mọi ô đồ nhặt.

---

## 1. Asset

| Asset | Dùng cho | Giấy phép | Ai tải | Trạng thái |
|---|---|---|---|---|
| [Old Door](https://sketchfab.com/3d-models/old-door-f2f77bd326c9486eaee65b87e84e9be9), Game Ready Art | 17 cánh cửa | CC BY 4.0 (phải ghi tên) | **Bạn** (Sketchfab cần đăng nhập) | Chờ tải |
| [Lotta tra Como](https://sketchfab.com/3d-models/lotta-tra-como-2554c38364d0432dba69bf721fb14e5e), Francesco Coldesina | Tủ lớn ở 4–5 phòng | CC BY 4.0 (phải ghi tên) | **Bạn** | Chờ tải |
| [Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit) | Bàn, ghế, kệ sách, sofa, bếp, nhà vệ sinh, cây cảnh, TV, đèn… | CC0 | Tôi (tải thẳng) | Chờ bạn đồng ý |
| [Kenney Car Kit](https://kenney.nl/assets/car-kit) | Xe rác / xe tải thay cho khối "VVVV" | CC0 | Tôi (tải thẳng) | Chờ bạn đồng ý; tôi sẽ kiểm tra có xe rác không khi tải |
| ~~[Trash Truck (Burnout 3)](https://sketchfab.com/3d-models/trash-truck-burnout-3-66b707150a7a45b69da06cc85497532a)~~ | ~~Xe~~ | Ghi CC BY, nhưng **nhiều khả năng trích từ game Burnout 3 của EA** | — | **Không dùng** (xem mục 6) |

Khi bạn tải từ Sketchfab: chọn định dạng **glTF** (hoặc GLB), giải nén vào `D:\DuAnLinhTinh\lethalCompany\assets\_incoming\` rồi báo tôi. Tôi sẽ kiểm tra file, đổi tên, chuyển vào đúng thư mục và ghi vào `CREDITS.md`.

Lưu ý tủ Lotta: 65.700 tam giác mỗi cái, khá nặng so với cả map. Tôi sẽ dùng **tối đa 6 cái** và đo FPS. Nếu máy yếu bị tụt khung hình, tôi chuyển các tủ ở xa sang tủ Kenney.

---

## 2. Bản đồ phòng

```
 col:  1      7 9     15 17 19 21    27 29    35
row 1 ┌─────────┬─────────┬─────┬─────────┬─────────┐
      │ P1      │ P2      │  H  │ P3      │ P4  (M) │   M = ma-nơ-canh xuất phát
      │ Lưu trữ ├D Giám   D  À  D Kho    D Phòng   │
      │         │  đốc    │  N  │ mẫu vải │ trưng bày│
row 6 └───D─────┴─────────┤  H  ├─────────┴───D─────┘
row 8 ┌─────────┬─────────┤     ├─────────┬─────────┐
      │ P5      │ P6      │  L  │ P7      │ P8      │
      │ Văn     D Phòng   D  A  D Văn     D Phòng   │
      │ phòng 1 │ họp     │  N  │ phòng 2 │ tủ đồ   │
row12 └─────────┴───D─────┤  G  ├───D─────┴─────────┘
row14 ┌─────────┬─────────┤     ├─────────┬─────────┐
      │ P9      │ P10     │     │ P11     │ P12     │
      │ Bảo vệ  D Lễ tân  D     D Pantry  D Vệ sinh │
      │         │         │     │         │         │
row19 └─────────┴─────────┴──D──┴─────────┴─────────┘
                              │  lối ra
         bãi xe:    P P   P P          [ XE RÁC ]
```

Mỗi phòng 7 × 6 m. Có 15 chỗ xuất hiện đồ nhặt (ô `i`), giữ nguyên.

---

## 3. Decor từng phòng

Ký hiệu nguồn: **[K]** Kenney Furniture Kit, **[L]** tủ Lotta, **[M]** mô hình ma-nơ-canh có sẵn.

| Phòng | Chủ đề | Đồ đặt | Ý đồ gameplay |
|---|---|---|---|
| **P1** góc trên trái | Phòng lưu trữ | 2 hàng kệ sách cao [K] chạy giữa phòng, tủ hồ sơ sát tường [K], thùng các-tông [K] | Kệ tạo **lối đi hẹp** và góc khuất: không nhìn được cả phòng cùng lúc |
| **P2** | Phòng giám đốc | Bàn làm việc lớn + ghế xoay [K], kệ sách [K], sofa + bàn trà [K], thảm [K], **1 tủ [L]** | Phòng "sang" nhất, dễ nhận ra |
| **P3** | Kho mẫu vải | Kệ chứa đồ [K], thùng [K], giá treo áo [K], **1 tủ [L]** | Bừa bộn, nhiều chỗ khuất |
| **P4** góc trên phải | Phòng trưng bày | Thảm [K], giá treo áo [K], gương/đèn đứng [K], **1 tủ [L]**, **2–3 ma-nơ-canh giả đứng im [M]** | Nơi ma-nơ-canh thật xuất phát. Ma-nơ-canh giả trông y hệt, nên người chơi không biết con nào sẽ di chuyển |
| **P5** | Văn phòng mở 1 | 4 bàn làm việc + máy tính + ghế [K], tủ hồ sơ [K], cây cảnh [K] | Không gian thoáng, nhìn xa được |
| **P6** | Phòng họp | Bàn dài + 6 ghế [K], TV trên tủ thấp [K], cây cảnh [K] | Bàn giữa phòng buộc phải đi vòng |
| **P7** | Văn phòng mở 2 | 4 bàn + ghế [K], máy in/photocopy (tủ thấp [K]), kệ [K] | Giống P5 nhưng xếp khác, tránh lặp |
| **P8** | Phòng tủ đồ nhân viên | **2 tủ [L]** dọc tường, ghế băng [K], giá treo [K] | Tủ cao che tầm nhìn, chỗ ma-nơ-canh dễ "nấp" |
| **P9** | Phòng bảo vệ | Bàn + 2 màn hình/TV [K], ghế [K], tủ hồ sơ [K], **1 tủ [L]** (nếu FPS ổn) | Gần lối vào, cảm giác "từng có người canh" |
| **P10** | Sảnh lễ tân | Quầy lễ tân (ghép bàn [K]), sofa chờ + bàn trà [K], cây cảnh [K], thảm [K] | Phòng đầu tiên người chơi gặp, tạo ấn tượng |
| **P11** | Pantry | Tủ bếp + bồn rửa + tủ lạnh [K], bàn tròn + 4 ghế [K], thùng rác [K] | Dễ nhận ra, làm mốc định hướng |
| **P12** | Nhà vệ sinh | Bồn cầu + bồn rửa + vách ngăn (đồ phòng tắm [K]) | Phòng nhỏ chia ngăn, góc nhìn hẹp |
| **Hành lang** | | Ghế băng, cây cảnh, thùng rác, bình nước [K] dọc tường, không chắn đường | Hành lang không còn trống trơn |
| **Bãi xe** | | Xe rác [Car Kit] thay khối "VVVV", thùng rác lớn [K] | Điểm chất đồ rõ ràng |

### Luật đặt đồ (để không phá gameplay)
1. **Không đặt đồ** trên ô cửa, ô đồ nhặt (`i`), ô xuất phát của quái (`M`), và **1 ô trước mỗi cửa**.
2. Lúc nào cũng phải đi được từ lối ra đến **mọi ô đồ nhặt** và **mọi phòng**. Có test tự động kiểm tra bằng navmesh.
3. Đồ to có va chạm. Quái và người chơi phải đi vòng, navmesh được bake sau khi đặt đồ. Đồ thấp (thảm) không có va chạm.
4. Đồ cao (tủ, kệ) **che tầm nhìn** của người chơi. Đây là chủ ý: tạo chỗ ma-nơ-canh di chuyển khuất mắt.
5. Toàn bộ đồ trang trí đứng yên và giống nhau trên mọi máy (đặt theo dữ liệu cố định), **không cần đồng bộ mạng**.

---

## 4. Cách làm (kỹ thuật)

- **Cửa:** thay khối hộp của cánh cửa bằng mô hình Old Door, giữ nguyên bản lề, va chạm và luật mở cửa do host quyết định. Mô hình sẽ được căn và co giãn cho vừa ô cửa 0,9 × 2,1 m.
- **Xe:** `Van` giữ nguyên chức năng (bấm E để chất đồ). Chỉ thay phần hình và hộp va chạm theo kích thước xe. Nếu xe dài hơn 4 ô, tôi sửa layout (thêm ô `V`).
- **Nội thất:** thêm thư mục `features/props/`:
  - `PropData`: mỗi loại đồ gồm mô hình, tỉ lệ, có va chạm hay không.
  - `greybox_01_decor.gd`: danh sách đặt đồ theo phòng (loại đồ, ô, góc xoay). Sửa decor chỉ cần sửa dữ liệu, không đụng code.
  - Level đặt đồ **trước khi bake navmesh**, để quái đi vòng qua đồ.
- **Ma-nơ-canh giả ở P4:** dùng lại `MannequinBody` với tư thế cố định, không có AI.
- **Kiểm tra:**
  - Test tự động: luật đặt đồ (mục 3); có đường đi tới mọi ô đồ nhặt và mọi phòng; quái vẫn đi tới và giết được người chơi.
  - Chụp màn hình từng phòng.
  - **Đo FPS** ở các phòng nặng nhất (P4, P8). Nếu tụt dưới 60 FPS: bớt bóng đổ của đồ nhỏ, hoặc thay tủ Lotta bằng tủ Kenney.

## 5. Các đợt làm

| Đợt | Việc | Cần trước |
|---|---|---|
| 1 | Cửa Old Door | Bạn tải Old Door |
| 2 | Xe rác | Bạn đồng ý tải Kenney Car Kit |
| 3 | Hệ thống đặt đồ + P10, P5, P6, hành lang (khu gần lối vào) | Bạn đồng ý tải Kenney Furniture Kit |
| 4 | P1, P2, P3, P7, P9, P11, P12 | |
| 5 | P4 (phòng trưng bày + ma-nơ-canh giả), P8 (tủ đồ) | Bạn tải tủ Lotta |
| 6 | Đo FPS, chỉnh, build lại | |
| 7 | Đồ nhặt đẹp (radio, hộp đồ nghề, đèn, bình gốm) | Chọn asset sau |

## 6. Về xe rác "Burnout 3"

- **Vì sao không dùng:** tài khoản đăng không có mô tả gì ngoài một câu đùa, còn tên và tag là game Burnout 3 của EA/Criterion. Nhiều khả năng mô hình được trích từ game. Nhãn CC BY do người đăng tự gắn không cho họ quyền cấp phép thứ họ không sở hữu.
- **Rủi ro:** dùng nó trong bản build gửi bạn bè là phát tán tài sản có bản quyền của EA.
- **Quy ước:** `docs/CONVENTIONS.md` mục 6 chỉ cho dùng asset có giấy phép đã kiểm tra.
- **Thay thế:** xe từ Kenney Car Kit (CC0). Nếu bạn muốn đúng kiểu xe rác chi tiết hơn, tôi có thể tìm mô hình xe rác CC0/CC BY do tác giả tự làm.
