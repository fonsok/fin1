# Step Management Guide

## How to Add New Steps Between Existing Steps

This guide shows how to add a new step between existing steps using the flexible step management system.

### Example: Adding a Verification Step Between Step 5 and 6

#### Step 1: Update the SignUpStep Enum

In `StepConfiguration.swift`, add the new case and update all subsequent step numbers:

```swift
enum SignUpStep: Int, CaseIterable, Identifiable {
    case welcome = 1
    case contact = 2
    case accountCreated = 3
    case personalInfo = 4
    case citizenshipTax = 5
    case verification = 6          // ← NEW STEP
    case identificationType = 7    // ← WAS 6, now 7
    case identificationUploadFront = 8  // ← WAS 7, now 8
    case identificationUploadBack = 9   // ← WAS 8, now 9
    case identificationConfirm = 10     // ← WAS 9, now 10
    case addressConfirm = 11            // ← WAS 10, now 11
    case addressConfirmSuccess = 12     // ← WAS 11, now 12
    case financial = 13                 // ← WAS 12, now 13
    case experience = 14                // ← WAS 13, now 14
    case nonInsiderDeclaration = 15     // ← WAS 14, now 15
    case moneyLaunderingDeclaration = 16 // ← WAS 15, now 16
    case terms = 17                     // ← WAS 16, now 17
    case summary = 18                   // ← WAS 17, now 18
}
```

#### Step 2: Add Step Information

Update the title, description, and icon properties in the same enum:

```swift
var title: String {
    switch self {
    // ... existing cases ...
    case .verification: return "Verification"
    // ... rest of cases ...
    }
}

var description: String {
    switch self {
    // ... existing cases ...
    case .verification: return "Additional verification required"
    // ... rest of cases ...
    }
}

var icon: String {
    switch self {
    // ... existing cases ...
    case .verification: return "checkmark.shield"
    // ... rest of cases ...
    }
}
```

#### Step 3: Create the Step View

Create a new Swift file `VerificationStep.swift`:

```swift
import SwiftUI

struct VerificationStep: View {
    @Binding var verificationCode: String
    @Binding var isVerified: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Additional Verification")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.fin1FontColor)
            
            Text("Please enter the verification code sent to your email")
                .font(.subheadline)
                .foregroundColor(.fin1FontColor.opacity(0.8))
                .multilineTextAlignment(.center)
            
            TextField("Verification Code", text: $verificationCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
            
            Button("Verify") {
                isVerified = true
            }
            .disabled(verificationCode.isEmpty)
            .buttonStyle(.borderedProminent)
        }
        .signUpHorizontalPadding()
    }
}
```

#### Step 4: Add Data Properties

In `SignUpData.swift`, add the required properties:

```swift
// Add these properties to SignUpData class
@Published var verificationCode: String = ""
@Published var isVerified: Bool = false
```

#### Step 5: Add Validation Logic

In `StepConfiguration.swift`, update the `DefaultStepValidation`:

```swift
func canProceedToNextStep(for step: SignUpStep, with data: SignUpData) -> Bool {
    switch step {
    // ... existing cases ...
    case .verification:
        return data.isVerified && !data.verificationCode.isEmpty
    // ... rest of cases ...
    }
}

func getValidationMessage(for step: SignUpStep, with data: SignUpData) -> String? {
    switch step {
    // ... existing cases ...
    case .verification:
        if data.verificationCode.isEmpty {
            return "Please enter the verification code"
        } else if !data.isVerified {
            return "Please verify the code"
        }
        return nil
    // ... rest of cases ...
    }
}
```

#### Step 6: Update SignUpView

In `SignUpView.swift`, add the new case to the switch statement:

```swift
@ViewBuilder
private var currentStepView: some View {
    switch coordinator.currentStep {
    // ... existing cases ...
    case .verification:
        VerificationStep(
            verificationCode: $signUpData.verificationCode,
            isVerified: $signUpData.isVerified
        )
    // ... rest of cases ...
    }
}
```

#### Step 7: Update SignUpCoordinator (if needed)

If you added the step information to the enum, you don't need to update the coordinator. If you didn't, add the step information to the coordinator's computed properties:

```swift
var currentStepTitle: String {
    switch currentStep {
    // ... existing cases ...
    case .verification: return "Verification"
    // ... rest of cases ...
    }
}
```

## Benefits of This System

✅ **Automatic numbering** - enum handles step numbers  
✅ **Type safety** - compile-time checking prevents errors  
✅ **Centralized validation** - all logic in one place  
✅ **Self-documenting** - step info defined in enum  
✅ **Easy maintenance** - add/remove/reorder steps easily  
✅ **No manual updates** - progress, navigation auto-update  
✅ **Future-proof** - scales to any number of steps  

## What You DON'T Need to Update

- Progress bar calculations (automatic)
- Navigation logic (automatic)
- Step counting (automatic)
- File organization (automatic)

## What You ONLY Need to Update

- Add new case to SignUpStep enum
- Create the new step view
- Add validation logic
- Add data properties to SignUpData
- Add case to SignUpView switch statement
