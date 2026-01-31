# 🎨 FIN1 Color Setup Guide

## 🚨 You need to create these colors in Xcode!

### Step 1: Open Assets.xcassets
1. In Xcode, click on `Assets.xcassets` in your project
2. Right-click in the Assets area
3. Select "New Color Set"

### Step 2: Create these 10 colors:

| Name | HEX Value | Usage |
|------|-----------|-------|
| `ScreenBackground` | `#193365` | Main background |
| `SectionBackground` | `#0d1933` | Card backgrounds |
| `AccentLightBlue` | `#007aff` | Primary buttons |
| `AccentGreen` | `#278e4c` | Success states |
| `AccentRed` | `#eb0000` | Error states |
| `AccentOrange` | `#ff9500` | Warning states |
| `InputFieldBackground` | `#8ea0ad` | Text field bg |
| `InputFieldPlaceholder` | `#536572` | Placeholder text |
| `InputText` | `#f5f5f5` | Input text |
| `FontColor` | `#f5f5f5` | Main text |

### Step 3: Set HEX values
1. Double-click the color swatch
2. Click gear icon → "Other..."
3. Enter the HEX value (e.g., #193365)
4. Press Enter

### Step 4: Set appearance
- In Attributes Inspector, set "Appearances" to "Any Appearance"

### Step 5: Test
- Build project (Cmd+B)
- Run app (Cmd+R)
- You should see the blue theme!

## 🚨 Important:
- Use exact names (case-sensitive)
- Set all to "Any Appearance"
- The app won't compile without these colors
