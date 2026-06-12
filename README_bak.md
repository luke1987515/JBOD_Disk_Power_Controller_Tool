# AIC JBOD 硬碟電源管理工具

此資料夾包含用於管理與控制 **AIC JBOD 擴充機箱** 硬碟電源（上電與斷電）的批次檔工具。

---

## 🛠️ 推薦使用：整合式工具

### 📌 [JBOD_Disk_Power_Controller_Tool.bat](file:///c:/Users/Administrator/Downloads/JBOD_On_OFF_HDD/JBOD_Disk_Power_Controller_Tool.bat)
這是將原本 6 個獨立批次檔功能整合在一起的單一互動式工具，具備自動偵測、手動設定及防錯確認機制。

#### **功能選單說明**：
1. **`[1] Power ON Disks (Staggered Spin-up)`**：
   * **功能**：批次開啟硬碟電源。
   * **安全機制**：為了防止所有硬碟同時啟動（Spin-up）造成瞬時啟動電流過大，觸發電源供應器（PSU）的過載保護或導致電壓不穩，此功能預設在每顆硬碟啟動之間加入 **25 秒的延遲**（分時喚醒）。
2. **`[2] Power OFF Disks (Fast shutdown)`**：
   * **功能**：批次關閉硬碟電源。
   * **安全機制**：每顆硬碟關閉間隔 **1 秒**。
3. **`[3] Exit`**：
   * 離開程式。

#### **執行步驟**：
1. **選擇操作**：選擇上電 (1) 或斷電 (2)。
2. **選擇 SCSI 裝置位址**：
   * 程式會自動執行 `sg_scan` 掃描並列出系統中目前已連接的 AIC 擴充器裝置供您選擇。
   * 若系統中未偵測到任何 AIC 擴充器裝置，程式會顯示錯誤訊息並返回主選單。
3. **自動偵測硬碟數量**：
   * 程式在您選擇 SCSI 裝置後，會自動透過 `sg_ses` 讀取描述符（Element Descriptor）來偵測該機箱的硬碟插槽數量。
   * 偵測成功後會詢問是否直接套用（預設為是），亦可選擇手動輸入自訂的硬碟數量。
4. **確認執行**：顯示完整設定摘要（操作、位址、數量、延遲時間），要求輸入 `y` 確認後才開始執行，防止誤觸。

---

## 💾 保留的舊腳本 (備用)
如果您需要進行無人值守的自動化排程或指令碼串接，仍可使用以下硬確定位址的舊腳本：
* **[sg_HDD_on_108.bat](file:///c:/Users/Administrator/Downloads/JBOD_On_OFF_HDD/sg_HDD_on_108.bat)**：上電 108 顆硬碟 (位址: `SCSI0:0,124,0`，延遲 25s)
* **[sg_HDD_off_108.bat](file:///c:/Users/Administrator/Downloads/JBOD_On_OFF_HDD/sg_HDD_off_108.bat)**：斷電 108 顆硬碟 (位址: `SCSI0:0,124,0`，延遲 1s)
* **[sg_HDD_on_108_0819.bat](file:///c:/Users/Administrator/Downloads/JBOD_On_OFF_HDD/sg_HDD_on_108_0819.bat)**：上電 108 顆硬碟 (位址: `SCSI0:1,9,0`，延遲 25s)
* **[sg_HDD_off_108_0819.bat](file:///c:/Users/Administrator/Downloads/JBOD_On_OFF_HDD/sg_HDD_off_108_0819.bat)**：斷電 108 顆硬碟 (位址: `SCSI0:1,9,0`，延遲 1s)
* **[sg_HDD_on_78.bat](file:///c:/Users/Administrator/Downloads/JBOD_On_OFF_HDD/sg_HDD_on_78.bat)**：上電 78 顆硬碟 (位址: `SCSI0:0,94,0`，延遲 25s)
* **[sg_HDD_off_78.bat](file:///c:/Users/Administrator/Downloads/JBOD_On_OFF_HDD/sg_HDD_off_78.bat)**：斷電 78 顆硬碟 (位址: `SCSI0:0,94,0`，延遲 1s)

---

## 📋 系統需求與依賴
* 本工具需要放置於含有 [sg_scan.exe](file:///c:/Users/Administrator/Downloads/JBOD_On_OFF_HDD/sg_scan.exe) 與 [sg_ses.exe](file:///c:/Users/Administrator/Downloads/JBOD_On_OFF_HDD/sg_ses.exe) 的資料夾中執行，或將 `sg3_utils` 的路徑設定於環境變數 (PATH) 中。
