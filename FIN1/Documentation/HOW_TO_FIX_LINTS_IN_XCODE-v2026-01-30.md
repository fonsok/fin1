# How to Fix Lints in Xcode

This guide explains how to view and fix SwiftLint errors directly in Xcode's Issues Navigator.

## Step 1: Add SwiftLint as a Build Phase

To see SwiftLint errors in Xcode's Issues Navigator, you need to add SwiftLint as a "Run Script Phase" in your build process.

### Instructions:

1. **Open your project in Xcode**
   - Open `FIN1.xcodeproj` in Xcode

2. **Select the FIN1 target**
   - In the Project Navigator (left sidebar), click on the project name `FIN1` (blue icon at the top)
   - Under "TARGETS", select `FIN1`

3. **Go to Build Phases tab**
   - Click on the **"Build Phases"** tab at the top

4. **Add a Run Script Phase**
   - Click the **"+"** button at the top left of the Build Phases section
   - Select **"New Run Script Phase"**

5. **Configure the SwiftLint script**
   - **Expand** the new "Run Script" phase (click the disclosure triangle)
   - **Name it**: Double-click "Run Script" and rename it to "SwiftLint"
   - **Move it up**: Drag it **above** the "Compile Sources" phase (linting should happen before compilation)
   - **Add the script**: In the script text area, paste this:

   ```bash
   if which swiftlint >/dev/null; then
     swiftlint
   else
     echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
   fi
   ```

6. **Configure script options** (optional but recommended):
   - ✅ Check **"Show environment variables in build log"** (for debugging)
   - ✅ Check **"Run script only when installing"** should be **UNCHECKED** (we want it to run on every build)
   - Leave **"Shell"** as `/bin/sh`
   - Leave **"Input Files"** and **"Output Files"** empty

7. **Save and build**
   - Press `Cmd + B` to build the project
   - SwiftLint will now run and show errors in the Issues Navigator

## Step 2: View Lint Errors in Xcode

After adding the build phase, lint errors will appear in Xcode's Issues Navigator:

1. **Open Issues Navigator**
   - Press `Cmd + 5` or click the **Issues Navigator** icon in the left sidebar (⚠️ icon)

2. **View errors**
   - All SwiftLint errors will appear as red error indicators (🔴)
   - Warnings appear as yellow warning indicators (🟡)
   - Click on any error to jump directly to the file and line

3. **Filter issues**
   - Use the filter at the bottom to show only errors, only warnings, or all issues
   - You can also filter by file or type

## Step 3: Fix Lint Errors

### Method 1: Fix Errors Directly in Xcode

1. **Click on an error** in the Issues Navigator
   - Xcode will automatically open the file and highlight the problematic line

2. **Read the error message**
   - The error message explains what's wrong (e.g., "Use ResponsiveDesign.font() instead of fixed fonts")

3. **Fix the code**
   - Make the necessary changes based on the error message
   - Common fixes:
     - Replace `.font(.title)` with `ResponsiveDesign.titleFont()`
     - Replace `VStack(spacing: 16)` with `VStack(spacing: ResponsiveDesign.spacing(6))`
     - Move ViewModel instantiation to `init()` method
     - Replace singleton usage with dependency injection

4. **Rebuild**
   - Press `Cmd + B` to rebuild
   - The error should disappear from the Issues Navigator

### Method 2: Auto-fix Some Issues

Some SwiftLint issues can be auto-fixed:

1. **Run SwiftLint with --fix flag**
   - Open Terminal in your project directory
   - Run: `swiftlint --fix`
   - This will automatically fix issues like:
     - Trailing whitespace
     - Formatting issues
     - Some style violations

2. **Note**: Custom rules (like ResponsiveDesign rules) cannot be auto-fixed and must be fixed manually

### Method 3: Fix All Errors at Once

1. **View all errors**
   - Open Issues Navigator (`Cmd + 5`)
   - Review all errors

2. **Fix systematically**
   - Group errors by type (e.g., all "No Fixed Fonts" errors)
   - Fix one type at a time
   - Rebuild after each batch to verify fixes

3. **Use Find & Replace** (for common patterns)
   - `Cmd + Shift + F` to open Find in Project
   - Use regex patterns to find and replace common violations
   - Example: Find `\.font\(\.title\)` and replace with `ResponsiveDesign.titleFont()`

## Step 4: Verify All Lints Are Fixed

1. **Build the project**
   - Press `Cmd + B`
   - Check that there are no errors in the Issues Navigator

2. **Run SwiftLint manually** (optional verification)
   - In Terminal: `swiftlint --strict`
   - This should show no errors or warnings

3. **Check CI requirements**
   - According to your project rules, all lints must pass before committing
   - Run: `swiftlint --strict` to ensure everything passes

## Common SwiftLint Errors and Fixes

### ResponsiveDesign Errors

| Error | Fix |
|-------|-----|
| `No Fixed Fonts` | Replace `.font(.title)` with `ResponsiveDesign.titleFont()` |
| `No Fixed Spacing` | Replace `VStack(spacing: 16)` with `VStack(spacing: ResponsiveDesign.spacing(6))` |
| `No Fixed Padding` | Replace `.padding(16)` with `.padding(ResponsiveDesign.spacing(4))` |
| `No Fixed Corner Radius` | Replace `.cornerRadius(8)` with `.cornerRadius(ResponsiveDesign.spacing(2))` |

### MVVM Architecture Errors

| Error | Fix |
|-------|-----|
| `No ViewModel Instantiation in View Body` | Move `@StateObject` initialization to `init()` method |
| `No Singleton Usage Outside Composition Root` | Inject service via constructor instead of using `.shared` |
| `No Data Formatting in Views` | Move formatting logic to ViewModel properties |
| `No Direct Service Access in Views` | Use `@Environment(\.appServices)` instead of `AppServices.live` |

## Troubleshooting

### SwiftLint not found

If you see "SwiftLint not installed" warning:

1. **Install SwiftLint via Homebrew:**
   ```bash
   brew install swiftlint
   ```

2. **Verify installation:**
   ```bash
   swiftlint version
   ```

3. **Rebuild the project**

### Errors not showing in Issues Navigator

1. **Check the build phase is added correctly**
   - Verify the Run Script phase is above "Compile Sources"
   - Verify the script is correct

2. **Clean build folder**
   - `Product` → `Clean Build Folder` (`Cmd + Shift + K`)
   - Rebuild (`Cmd + B`)

3. **Check SwiftLint configuration**
   - Verify `.swiftlint.yml` exists in the project root
   - Verify `reporter: xcode` is set (it should be)

### Too many errors at once

1. **Focus on errors first** (red indicators)
   - Warnings can be addressed later
   - Errors block builds

2. **Fix by file**
   - Open one file at a time
   - Fix all errors in that file
   - Move to the next file

3. **Use Find & Replace for common patterns**
   - This is faster for systematic violations

## Best Practices

1. **Fix lints as you code**
   - Don't let errors accumulate
   - Fix them immediately after writing code

2. **Run SwiftLint before committing**
   - Always run `swiftlint --strict` before committing
   - This ensures CI will pass

3. **Review Issues Navigator regularly**
   - Check it after each build
   - Keep the codebase clean

4. **Understand the rules**
   - Read `.cursor/rules/swiftlint.md` to understand why rules exist
   - This helps you write compliant code from the start

## Additional Resources

- **SwiftLint Rules**: See `.cursor/rules/swiftlint.md`
- **SwiftLint Configuration**: See `.swiftlint.yml`
- **Architecture Rules**: See `.cursor/rules/architecture.md`
- **CI Requirements**: See `.cursor/rules/ci-cd.md`











