# Spacing Terminology & Layer Structure

## 🏗️ Layer Structure

```
┌─────────────────────────────────────┐ ← Device Screen Border
│ 0) ScreenBackground (Light Blue)    │
│ ┌─────────────────────────────────┐ │
│ │ 1) Light Blue Area             │ │ ← ScrollView background
│ │ ┌─────────────────────────────┐ │ │
│ │ │ 2) ScrollSection            │ │ │ ← ScrollSection
│ │ │ ┌─────────────────────────┐ │ │ │
│ │ │ │ Step Content            │ │ │ │ ← Individual step content
│ │ │ └─────────────────────────┘ │ │ │
│ │ └─────────────────────────────┘ │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

## 📏 Terminology Clarification

### **Padding vs Margin:**
- **Padding**: Space **INSIDE** a layer/scrollsection (between the border and content)
- **Margin**: Space **OUTSIDE** a layer/scrollsection (between this layer and the layer below)

### **Key Principle:**
**Space outside (margin) is always measured from the layer below border, NOT from the device screen border.**

## 🔧 Implementation

### **Layer 2: ScrollSection**
```swift
// Creates the scrollsection with proper margin from Light Blue Area
.scrollSection(
    horizontalMargin: 16,    // MARGIN from Layer 1 (Light Blue Area)
    verticalMargin: 16,      // MARGIN from Layer 1 (Light Blue Area)
    cornerRadius: 12
)
```

### **Layer 3: Step Content**
```swift
// Individual step content with internal padding
VStack {
    // Step content
}
.padding()  // PADDING within the step content area
.background(Color.fin1SectionBackground)
.cornerRadius(16)
```

## 🎯 Current Configuration

### **SignUpView Implementation:**
```swift
ScrollView {
    VStack(spacing: 24) {
        currentStepView
    }
    .padding(.top, 32)
    .padding(.bottom, 32)
    .padding(.horizontal, SpacingConfig.scrollSectionHorizontalPadding)  // ← 16px from Light Blue Area
    .background(Color.fin1ScrollSectionBackground)
    .cornerRadius(12)
}
.padding(.horizontal, SpacingConfig.lightBlueAreaHorizontalPadding)  // ← 8px from device edges
```

### **SpacingConfig:**
```swift
static let lightBlueAreaHorizontalPadding: CGFloat = 8   // ← 8px from device edges
static let scrollSectionHorizontalPadding: CGFloat = 16  // ← 16px from Light Blue Area edges
```

## 🔄 Migration from Old System

### **Current Implementation:**
```swift
.scrollSection(
    horizontalMargin: 16,    // Clear: margin from light blue area
    verticalMargin: 16       // Clear: margin from light blue area
)
```

## 📝 Usage Examples

### **Setting Margin from Light Blue Area:**
```swift
// In SpacingConfig.swift
static let signUpHorizontalPadding: CGFloat = 0   // No margin from light blue area
static let signUpHorizontalPadding: CGFloat = 8   // 8px margin from light blue area (current)
static let signUpHorizontalPadding: CGFloat = 16  // 16px margin from light blue area
static let signUpHorizontalPadding: CGFloat = 32  // 32px margin from light blue area
```

### **Setting Internal Padding:**
```swift
// In individual steps
VStack {
    // Content
}
.padding()  // 16px padding within the step content
```

## ✅ Benefits of New System

1. **Clear Terminology**: No more confusion between margin and padding
2. **Explicit Control**: Separate control over margin and padding
3. **Better Documentation**: Self-documenting parameter names
4. **Backward Compatibility**: Old methods still work
5. **Consistent Behavior**: All steps use the same spacing mechanism
