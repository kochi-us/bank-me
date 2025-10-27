# bank-management

SwiftUI + SwiftData の家計簿/銀行管理アプリ。
## 💾 Backup Information

This project includes a backup of the app’s internal state data.

- **Backup file:** `Resources/InitialState/state.json`
- **Source location on macOS:**  
  `/Users/<username>/Library/Containers/com.kochi.bank-management/Data/Library/Application Support/com.kochi.bank-management/state.json`
- **Purpose:**  
  To preserve the latest user data (accounts, categories, and transactions) from the app.

### 🔁 How to Update the Backup

When the app data changes, update the backup file with the following commands:

```bash
cp "~/Library/Containers/com.kochi.bank-management/Data/Library/Application Support/com.kochi.bank-management/state.json" Resources/InitialState/state.json
git add Resources/InitialState/state.json
git commit -m "Update backup: state.json"
git push


---

📍次にやること：
1. Xcode のプロジェクトナビゲータで `README.md` を開く  
2. 上記の内容を一番下に貼り付ける  
3. 保存して  
   ```bash
   git add README.md
   git commit -m "Add backup instructions to README"
   git push
