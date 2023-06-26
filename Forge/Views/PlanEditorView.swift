import SwiftUI

struct PlanEditorView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var viewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct PlanEditorView_Previews: PreviewProvider {
    static var previews: some View {
        PlanEditorView()
            .preferredColorScheme(.dark)
    }
}
