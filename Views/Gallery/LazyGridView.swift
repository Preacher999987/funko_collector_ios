//
//  ContentView.swift
//  FunkoCollector
//
//  Created by Pedro Rojas on 29/09/21.
//

import SwiftUI
import PhotosUI // Import PhotosUI for PHPickerViewController

struct LazyGridGalleryView: View {
    @Namespace private var animationNamespace // For matchedGeometryEffect
    @State private var selectedItem: Int? = nil {
        didSet {
            if selectedItem != oldValue {
                loadGalleryImages()
            }
        }
    } // Track the selected grid item
    @State private var isFullScreen: Bool = false // Track full-screen state
    @State private var selectedBackgroundImage: UIImage? = nil // Store the selected background image
    @State private var isShowingImagePicker: Bool = false // Control the image picker presentation
    
    @State private var showAddToCollectionConfirmation = false
    @State private var isLoadingRelated = false
    // State property to manage gallery carousel
    @State private var currentImageIndex: Int = 0
    
    @State private var showDeleteConfirmation = false
    
    @State private var showAddMenu = false
    @State private var isPresentingScanner = false
    
    // Create an instance of the ViewModel
    @StateObject private var viewModel = LazyGridViewModel()
    
    @EnvironmentObject var appState: AppState
    
    private static let size: CGFloat = 150
    private static let spacingBetweenColumns: CGFloat = 12
    private static let spacingBetweenRows: CGFloat = 12
    private static let totalColumns: Int = 4
    
    @Binding var payload: [Collectible]
    
    var dismissAction: () -> Void
    
    var dismissActionWrapped: () -> Void {
        get {
            return {
                if isFullScreen {
                    withAnimation {
                        isFullScreen = false
                    }
                } else {
                    selectedItem = nil
                    dismissAction()
                }
            }
        }
    }
    
    var seeMissingPopsAction: (Collectible) -> Void
    
    var gridItems = Array(
        repeating: GridItem(
            .fixed(size),
            spacing: spacingBetweenColumns,
            alignment: .center
        ),
        count: totalColumns
    )
    
    private var backgroundView: some View {
        Group {
            if let backgroundImage = selectedBackgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea([.all])
            } else {
                Image("background-image-1")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea([.all])
            }
        }
    }
    
    private var topButtonsBar: some View {
        VStack {
            ZStack {
                HStack {
                    // Back Button
                    if appState.showBackButton {
                        Button(action: dismissActionWrapped) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.black).opacity(0.8)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .padding(.leading, 20)
                        Spacer()
                    }
                }
                
                // Centered Logo Image
                Image(.gridItemPlaceholder) // Replace with your actual asset name
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40) // Adjust size as needed
                
                HStack {
                    Spacer()
                    // Add to Collection Button (new)
                    if appState.showAddToCollectionButton {
                        Button(action: {
                            showAddToCollectionConfirmation = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                
                                Text("Collection")
                                    .font(.system(size: 14, weight: .medium))
                                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.9))
                                    .shadow(radius: 2)
                            )
                            .foregroundColor(.green)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.green, lineWidth: 1)
                            )
                        }
                        .padding(.trailing, appState.showPlusButton ? 10 : 20)
                        .alert("Add to Collection", isPresented: $showAddToCollectionConfirmation) {
                            Button("Add", action: addToCollection)
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Add these items to your permanent Collection?")
                        }
                    }
                    
                    // Plus Button
                    if appState.showPlusButton {
                        Menu {
                            Button(action: {
                                isPresentingScanner = true
                            }) {
                                Label("Scan Barcode", systemImage: "barcode.viewfinder")
                            }
                            
                            Button(action: {
                                // Handle photo addition
                            }) {
                                Label("Add by Photo", systemImage: "photo")
                            }
                            
                            Button(action: {
                                // Handle manual addition
                            }) {
                                Label("Add Manually", systemImage: "keyboard")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .rotationEffect(.degrees(showAddMenu ? 45 : 0))
                                .animation(.spring(), value: showAddMenu)
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                        .menuIndicator(.hidden)
                        .sheet(isPresented: $isPresentingScanner) {
                            BarcodeScannerView { items in
                                payload.append(contentsOf: items)
                            }
                        }
                    }
                    
                    // Ellipsis Button
                    if appState.showEllipsisButton {
                        Button(action: {
                            isShowingImagePicker = true
                        }) {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.black).opacity(0.8)
                                .background(Color.gray)
                                .clipShape(Circle())
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .padding(.trailing, 20)
                    }
                    
                    if appState.showCollectionButton {
                        // Add Collection View button
                        Button(action: {
                            appState.openMyCollection = true
                            appState.showCollectionButton = false
                            appState.showAddToCollectionButton = false
                            dismissAction()
                        }) {
                            Text("My Collection")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.black.opacity(0.7))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.blue, lineWidth: 1.5)
                                        )
                                )
                                .shadow(radius: 2)
                        }
                        .padding(.trailing, 20)
                    }
                }
            }
            .padding(.top, 40)
            .frame(height: 84) // Total height including top padding
            Spacer()
        }
        .zIndex(2)
    }
    
    private func addToCollection() {
        // Implement your Collection saving logic here
        print("Adding items to Collection: \(payload)")
        do {
            // Add all current payload items to Collection
            try payload.forEach { item in
                try FunkoDatabase.addItem(item)
            }
            
            appState.openMyCollection = true
            appState.showPlusButton = true
            appState.showEllipsisButton = true
            appState.showCollectionButton = false
            appState.showAddToCollectionButton = false
            dismissAction()
        } catch {
            print("Error saving to Collection:", error.localizedDescription)
        }
    }
    
    
    private func gridItemView(for index: Int, proxy: GeometryProxy) -> some View {
        ZStack {
            AsyncImageLoader(
                url: viewModel.getGridItemUrl(from: payload[index]),
                placeholder: Image(.gridItemPlaceholder),
                grayScale: !payload[index].inCollection
            )
            .scaledToFit()
            .cornerRadius(Self.size/8)
            .scaleEffect(scale(proxy: proxy, value: index))
            .offset(x: offsetX(index), y: 0)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedItem = index
                }
            }
            
            // MISSING label - matches xmark button position/size
            if !payload[index].inCollection {
                Text("MISSING")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                
                    .frame(width: .infinity, height: 24)
                    .background(Color.red)
                    .cornerRadius(12)
                    .offset(x: offsetX(index) + Self.size / 4 - 10, y: -Self.size / 2 + 10)
            }
            
            if selectedItem == index {
                if !payload[index].inCollection {
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedItem = index
                            isFullScreen = true
                        }
                    }) {
                        Text("Shop")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: Self.size / 2, height: 30)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    .offset(x: offsetX(index), y: 0)
                } else {
                    Button(action: {
                        // Trigger haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        withAnimation(.spring()) {
                            selectedItem = index
                            isFullScreen = true
                        }
                    }) {
                        Text("View")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                            .frame(width: Self.size / 2, height: 30)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.green, lineWidth: 1)
                            )
                    }
                    .offset(x: offsetX(index), y: 0)
                }
                if payload[index].inCollection {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.black).opacity(0.8)
                            .background(.red)
                            .clipShape(Circle())
                    }
                    .frame(width: 44, height: 44) // Minimum tappable area
                    .contentShape(Circle()) // Makes entire circle tappable
                    .offset(x: offsetX(index) + Self.size / 2 - 10, y: -Self.size / 2 + 10)
                    .alert("Delete \(payload[index].attributes.name)?", isPresented: $showDeleteConfirmation) {
                        Button("Delete", role: .destructive, action: confirmDeletion)
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently remove the item from your collection.")
                    }
                }
            }
        }
    }
    
    private func confirmDeletion() {
        showDeleteConfirmation = false
        withAnimation(.easeOut(duration: 0.3)) {
            if let index = selectedItem {
                // Remove the item from the data source
                try? FunkoDatabase.deleteItem(for: payload[index].id)
                payload.remove(at: index)
                // Reset selection
                selectedItem = nil
            }
        }
    }
    
    private func fullScreenView(for index: Int) -> some View {
        // Get the current item from payload
        let currentItem = payload[index]
        let galleryImages = currentItem.attributes.images.gallery ?? []
        
        return VStack(spacing: 20) {
            // Carousel View
            ZStack {
                // Image Carousel with conditional offset
                TabView(selection: $currentImageIndex) {
                    ForEach(Array(galleryImages.enumerated()), id: \.offset) { index, imageData in
                        GeometryReader { geometry in
                            AsyncImageLoader(
                                url: URL(string: imageData.url),
                                placeholder: Image(.gridItemPlaceholder),
                                grayScale: false
                            )
                            //                        .frame(height: !isFullScreen ? 200 : 200)
                            .scaledToFit()
                            
                            .clipShape(RoundedRectangle(cornerRadius: 20)) // <-- Same as details view
                            //                            .applyConditionalScaling(isScaledToFit: isFullScreen)
                            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                            //                            .clipped()
                            .tag(index)
                            .gesture(
                                TapGesture()
                                    .onEnded {
                                        if !isFullScreen {
                                            withAnimation(.spring()) {
                                                isFullScreen = true
                                            }
                                        }
                                    }
                                    .exclusively(before:
                                                    DragGesture()
                                        .onEnded { gesture in
                                            if gesture.translation.height > 100 {
                                                withAnimation(.spring()) {
                                                    isFullScreen = false
                                                }
                                            }
                                        }
                                                )
                            )
                        }
                    }
                }
                .background(
                    ZStack {
                        // Blur layer with bottom-to-top fade
                        VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                            .opacity(isFullScreen ? 0 : 1)
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .black, location: 0.4)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Optional subtle bottom shadow
                        //                                Rectangle()
                        //                                    .frame(height: 20)
                        //                                    .foregroundStyle(
                        //                                        LinearGradient(
                        //                                            colors: [.black.opacity(0.15), .clear],
                        //                                            startPoint: .bottom,
                        //                                            endPoint: .top
                        //                                        )
                        //                                    )
                        //                                    .offset(y: 20)
                    }
                        .edgesIgnoringSafeArea(.bottom)
                )
                
                //                .background(Color.green.edgesIgnoringSafeArea(.all))
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: isFullScreen ? .always : .never))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                //                .offset(y: !isFullScreen ? 400 : 0)  // Half of 300 to maintain visual balance
                
                // Navigation Arrows
                if galleryImages.count > 1 {
                    HStack {
                        Button(action: {
                            withAnimation {
                                currentImageIndex = (currentImageIndex - 1 + galleryImages.count) % galleryImages.count
                            }
                        }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .opacity(0.8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                currentImageIndex = (currentImageIndex + 1) % galleryImages.count
                            }
                        }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .opacity(0.8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 20)
                    }
                    .offset(y: !isFullScreen ? 40 : 0) // <-- Also offset the navigation buttons
                }
            }
            .frame(height: !isFullScreen ? 500 : 500)
            .matchedGeometryEffect(id: index, in: animationNamespace)
            
            // Details View
            if isFullScreen {
                VStack(spacing: 10) {
                    detailRow(title: "ITEM:", value: currentItem.attributes.name)
                    detailRow(title: "VALUE:", value: currentItem.estimatedValue ?? "N/A")
                    
                    Button(action: {
                        seeMissingPopsAction(currentItem)
                    }) {
                        Text("See missing pops")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(height: 30)
                            .padding(.horizontal, 20)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    .padding(.top, 10)
                }
                .padding(.vertical, 20)
                .background(Color.gray.opacity(0.4))
                .cornerRadius(20)
                .padding(.bottom, 60)
                .padding(.horizontal, 20)
            }
        }
        //        .padding(.horizontal, 20)
        .transition(.opacity)
        .onAppear {
            currentImageIndex = 0
        }
    }
    
    struct VisualEffectView: UIViewRepresentable {
        var effect: UIVisualEffect?
        
        func makeUIView(context: Context) -> UIVisualEffectView {
            UIVisualEffectView(effect: effect)
        }
        
        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
            uiView.effect = effect
        }
    }
    
    private var detailsView: some View {
        VStack(spacing: 10) {
            detailRow(title: "TYPE:", value: "Pop!")
            detailRow(title: "RELEASE:", value: "2024")
            detailRow(title: "STATUS:", value: "Vaulted")
            detailRow(title: "ITEM #:", value: "1604")
            detailRow(title: "SERIES:", value: "Arcane - League of Legends")
            detailRow(title: "ESTIMATED PRICE", value: "£35")
        }
        .layoutPriority(1)
        .padding(.vertical, 20)
        .background(Color.gray.opacity(0.4))
        .cornerRadius(20)
        .padding(.bottom, 60)
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
    }
    
    var body: some View {
        ZStack {
            backgroundView
            topButtonsBar
            
            if isLoadingRelated {
                ProgressView()
                    .scaleEffect(2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .zIndex(3) // Show above other content
            }
            
            //            VStack {
            if !isFullScreen {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    LazyVGrid(
                        columns: gridItems,
                        alignment: .center,
                        spacing: Self.spacingBetweenRows
                    ) {
                        ForEach(payload.indices, id: \.self) { index in
                            GeometryReader { proxy in
                                gridItemView(for: index, proxy: proxy)
                            }
                            .frame(height: Self.size)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity).combined(with: .move(edge: .trailing))
                            ))
                        }
                    }
                    .padding(.trailing, Self.size/2) // Add proper padding
                    .padding(.top, Self.size/2 + 20)
                    .padding(.bottom, Self.size/2)
                    .padding(.leading, 20)
                }
                .contentShape(Rectangle()) // Make entire scroll view tappable
                .gesture(
                    TapGesture()
                        .onEnded {
                            if !isFullScreen {
                                withAnimation(.spring()) {
                                    selectedItem = nil
                                }
                            }
                        }
                )
                .sheet(isPresented: $isShowingImagePicker) {
                    ImagePicker(selectedImage: $selectedBackgroundImage)
                }
            }
            
            if let selectedItem = selectedItem {
                fullScreenView(for: selectedItem)
                    .offset(y: !isFullScreen ? UIScreen.main.bounds.height*0.5 : 0)  // Half of 300 to maintain visual balance
            }
            //            }
        }
        .onAppear {
            if appState.openRelated {
                loadRelatedItems()
            }
        }
    }
    
    private func loadGalleryImages() {
        guard let selectedIndex = selectedItem,
              selectedIndex < payload.count else {
            print("No valid item selected")
            return
        }
        
        if !payload[selectedIndex].gallery.isEmpty {
            return
        }
        
        let currentItemid = payload[selectedIndex].id
        
        viewModel.getGalleryImages(for: currentItemid) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let images):
                    // Update the selected item in the database
                    try? FunkoDatabase.updateGallery(by: currentItemid, galleryImages: images)
                    payload[selectedIndex].attributes.images.gallery = images
                    
                    print("Successfully updated gallery for item: \(payload[selectedIndex].attributes.name)")
                case .failure(let error):
                    print("Failed to load details: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadRelatedItems() {
        guard !payload.isEmpty else { return }
        
        isLoadingRelated = true
        viewModel.getRelated(for: payload[0].id) { items in
            DispatchQueue.main.async {
                isLoadingRelated = false
                
                // Process new items with inCollection flag
                let myCollection = (try? FunkoDatabase.loadItems()) ?? []
                let newItems = items.compactMap { newItem -> Collectible? in
                    // Skip duplicates
                    guard !payload.contains(where: { $0.id == newItem.id }) else {
                        return nil
                    }
                    
                    // Check if item exists in collection
                    let inCollection = myCollection.contains { $0.id == newItem.id }
                    
                    // Return modified item
                    var modifiedItem = newItem
                    modifiedItem.inCollection = inCollection
                    return modifiedItem
                }
                
                // Add to payload with animation
                if !newItems.isEmpty {
                    withAnimation(.easeInOut) {
                        payload.append(contentsOf: newItems)
                    }
                    print("Added \(newItems.count) new related items")
                }
            }
        }
    }
    
    func offsetX(_ value: Int) -> CGFloat {
        let rowNumber = value / gridItems.count
        
        if rowNumber % 2 == 0 {
            return Self.size/2 + Self.spacingBetweenColumns/2
        }
        
        return 0
    }
    
    func appName(_ value: Int) -> String {
        apps[value%apps.count]
    }
    
    var center: CGPoint {
        CGPoint(
            x: UIScreen.main.bounds.size.width*0.5,
            y: UIScreen.main.bounds.size.height*0.5
        )
    }
    
    // This was my hardcoded approach... really bad for the future!
    //    var deviceCornerAngle: CGFloat {
    //        if UIDevice.current.userInterfaceIdiom == .pad {
    //            return (UIDevice.current.orientation == .portrait) ? 55 : 35
    //        } else {
    //            return (UIDevice.current.orientation == .portrait) ? 65 : 25
    //        }
    //    }
    
    func scale(proxy: GeometryProxy, value: Int) -> CGFloat {
        let rowNumber = value / gridItems.count
        
        // We need to consider the offset for even rows!
        let x = (rowNumber % 2 == 0)
        ? proxy.frame(in: .global).midX + proxy.size.width/2
        : proxy.frame(in: .global).midX
        
        let y = proxy.frame(in: .global).midY
        let maxDistanceToCenter = getDistanceFromEdgeToCenter(x: x, y: y)
        
        let currentPoint = CGPoint(x: x, y: y)
        let distanceFromCurrentPointToCenter = distanceBetweenPoints(p1: center, p2: currentPoint)
        
        // This creates a threshold for not just the pure center could get
        // the max scaleValue.
        let distanceDelta = min(
            abs(distanceFromCurrentPointToCenter - maxDistanceToCenter),
            maxDistanceToCenter*0.3
        )
        
        // Helps to get closer to scale 1.0 after the threshold.
        let scalingFactor = 3.3
        let scaleValue = distanceDelta/(maxDistanceToCenter) * scalingFactor
        
        return scaleValue
    }
    
    func getDistanceFromEdgeToCenter(x: CGFloat, y: CGFloat) -> CGFloat {
        let m = slope(p1: CGPoint(x: x, y: y), p2: center)
        let currentAngle = angle(slope: m)
        
        let edgeSlope = slope(p1: .zero, p2: center)
        let deviceCornerAngle = angle(slope: edgeSlope)
        
        if currentAngle > deviceCornerAngle {
            let yEdge = (y > center.y) ? center.y*2 : 0
            let xEdge = (yEdge - y)/m + x
            let edgePoint = CGPoint(x: xEdge, y: yEdge)
            
            return distanceBetweenPoints(p1: center, p2: edgePoint)
        } else {
            let xEdge = (x > center.x) ? center.x*2 : 0
            let yEdge = m * (xEdge - x) + y
            let edgePoint = CGPoint(x: xEdge, y: yEdge)
            
            return distanceBetweenPoints(p1: center, p2: edgePoint)
        }
    }
    
    func distanceBetweenPoints(p1: CGPoint, p2: CGPoint) -> CGFloat {
        let xDistance = abs(p2.x - p1.x)
        let yDistance = abs(p2.y - p1.y)
        
        return CGFloat(
            sqrt(
                pow(xDistance, 2) + pow(yDistance, 2)
            )
        )
    }
    
    func slope(p1: CGPoint, p2: CGPoint) -> CGFloat {
        return (p2.y - p1.y)/(p2.x - p1.x)
    }
    
    func angle(slope: CGFloat) -> CGFloat {
        return abs(atan(slope) * 180 / .pi)
    }
}

struct Axes: View {
    var body: some View {
        
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: geometry.frame(in: .global).maxX, y: geometry.frame(in: .global).midY))
                path.addLine(to: CGPoint(x: 0, y: geometry.frame(in: .global).midY))
                path.move(to: CGPoint(x: geometry.frame(in: .global).midX, y: geometry.frame(in: .global).midY))
                path.addLine(to: CGPoint(x: geometry.frame(in: .global).midX, y: geometry.frame(in: .global).maxY))
                
                path.addLine(to: CGPoint(x: geometry.frame(in: .global).midX, y: geometry.frame(in: .global).minY - 60))
            }
            .stroke(Color.blue, lineWidth: 3)
        }
    }
}

// Image Picker using PHPickerViewController
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images // Allow only images to be selected
        configuration.selectionLimit = 1 // Allow only one image to be selected
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else { return }
            
            // Load the selected image
            result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image // Set the selected image as the background
                    }
                }
            }
        }
    }
}

// Custom View Modifier for Conditional Scaling
extension View {
    @ViewBuilder
    func applyConditionalScaling(isScaledToFit: Bool) -> some View {
        if isScaledToFit {
            self.scaledToFit() // Apply .scaledToFit() if condition is true
        } else {
            self.scaledToFill() // Apply .scaledToFill() if condition is false
        }
    }
}
