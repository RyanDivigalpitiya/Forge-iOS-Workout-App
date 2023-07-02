
// testing WOrkoutInProgressView indexing calculations:
let s = [1,2,3,4]
print("\(s.count) sets")
for i in 1...s.count*2-1 {
    if i%2 == 1 {
        print("Set index: \((i/2))")
    } else if i%2 == 0 {
        print("Timer")
    }
}

//if setIndex%2 == 1 {
//
//    // set view
//    HStack {
//        Button(action: {
//            // toggle set completion
//        }) {
//            Circle()
//                .stroke(lineWidth: 2)
//                .frame(width: 25, height: 25)
//                .foregroundColor(fgColor)
//                .padding(5)
//        }
//        SetView(setIndex: setIndex, exerciseIndex: exerciseIndex, uniqueSets: true)
//    }
//
//} else if setIndex%2 == 0 {
//    // timer view
//}

let sets = 4
var setCompletions: [Bool] = []
for _ in 1...sets {
    setCompletions.append(false)
}
print(setCompletions)
