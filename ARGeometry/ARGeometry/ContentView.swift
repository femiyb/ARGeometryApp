import SwiftUI
import RealityKit
import ARKit
import Vision
import CoreML

// Main Content View
struct ContentView: View {
    @State private var selectedShape: ShapeType = .cube // State variable to track selected shape
    @State private var sideLength: String = "3"    // Default side length in cm for Cube
    @State private var radius: String = "1.5"     // Default radius in cm for Sphere
    @State private var baseLength: String = "3"   // Default base length in cm for Pyramid
    @State private var height: String = "2"       // Default height in cm for Pyramid
    
    var body: some View {
        VStack {
            ZStack {
                // AR View
                ARViewContainer(
                    selectedShape: $selectedShape,
                    sideLength: $sideLength,
                    radius: $radius,
                    baseLength: $baseLength,
                    height: $height
                ).edgesIgnoringSafeArea(.all)
            }
            
            // Buttons for shape selection
            HStack {
                Button(action: { selectedShape = .cube }) {
                    Text("Cube")
                        .padding()
                        .background(selectedShape == .cube ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: { selectedShape = .sphere }) {
                    Text("Sphere")
                        .padding()
                        .background(selectedShape == .sphere ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: { selectedShape = .pyramid }) {
                    Text("Pyramid")
                        .padding()
                        .background(selectedShape == .pyramid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: { selectedShape = .octagon }) {
                    Text("Octagon")
                        .padding()
                        .background(selectedShape == .octagon ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            
            // User Input for dynamic shape sizes
            if selectedShape == .cube {
                TextField("Enter Side Length in cm", text: $sideLength)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else if selectedShape == .sphere {
                TextField("Enter Radius in cm", text: $radius)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else if selectedShape == .pyramid {
                TextField("Enter Base Length in cm", text: $baseLength)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Enter Height in cm", text: $height)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
}

// ARView Container to manage AR functionalities
struct ARViewContainer: UIViewRepresentable {
    @Binding var selectedShape: ShapeType
    @Binding var sideLength: String
    @Binding var radius: String
    @Binding var baseLength: String
    @Binding var height: String
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Setup AR configuration
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        // Set the AR session delegate for object detection
        arView.session.delegate = context.coordinator
        
        // Add Gesture Recognizers
        let tapGestureRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGestureRecognizer)
        
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinchGestureRecognizer.delegate = context.coordinator
        arView.addGestureRecognizer(pinchGestureRecognizer)
        
        let rotationGestureRecognizer = UIRotationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRotation(_:)))
        rotationGestureRecognizer.delegate = context.coordinator
        arView.addGestureRecognizer(rotationGestureRecognizer)
        
        context.coordinator.arView = arView
        context.coordinator.updateBindings(
            selectedShape: $selectedShape,
            sideLength: $sideLength,
            radius: $radius,
            baseLength: $baseLength,
            height: $height
        )
        
        context.coordinator.createShape(ofType: selectedShape) // Create the initial shape
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        guard !context.coordinator.isPinchGestureActive else { return }
        
        // Only update if the values have changed to avoid overriding gesture updates
        if let currentSideLength = Double(sideLength), currentSideLength / 100.0 != context.coordinator.sideLength {
            context.coordinator.sideLength = currentSideLength / 100.0
        }
        if let currentRadius = Double(radius), currentRadius / 100.0 != context.coordinator.radius {
            context.coordinator.radius = currentRadius / 100.0
        }
        if let currentBaseLength = Double(baseLength), currentBaseLength / 100.0 != context.coordinator.baseLength {
            context.coordinator.baseLength = currentBaseLength / 100.0
        }
        if let currentHeight = Double(height), currentHeight / 100.0 != context.coordinator.height {
            context.coordinator.height = currentHeight / 100.0
        }
        
        context.coordinator.createShape(ofType: selectedShape)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // Coordinator class to handle gesture events
    class Coordinator: NSObject, UIGestureRecognizerDelegate, ARSessionDelegate {
        var frameCounter = 0
        let frameInterval = 10 // Perform detection every 10 frames
        
        var arView: ARView?
        var currentEntity: ModelEntity?
        var textEntity: Entity?
        
        var sideLength: Double = 0.03
        var radius: Double = 0.015
        var baseLength: Double = 0.03
        var height: Double = 0.02
        
        var selectedShapeBinding: Binding<ShapeType>?
        var sideLengthBinding: Binding<String>?
        var radiusBinding: Binding<String>?
        var baseLengthBinding: Binding<String>?
        var heightBinding: Binding<String>?
        
        // Flag to indicate when the pinch gesture is active
        var isPinchGestureActive: Bool = false
        
        // Object Detector
        private var objectDetector: ObjectDetector?
        
        override init() {
            super.init()
            objectDetector = ObjectDetector()
        }
        
        func updateBindings(
            selectedShape: Binding<ShapeType>,
            sideLength: Binding<String>,
            radius: Binding<String>,
            baseLength: Binding<String>,
            height: Binding<String>
        ) {
            self.selectedShapeBinding = selectedShape
            self.sideLengthBinding = sideLength
            self.radiusBinding = radius
            self.baseLengthBinding = baseLength
            self.heightBinding = height
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func createShape(ofType shapeType: ShapeType) {
            guard let arView = arView else { return }
            
            currentEntity?.removeFromParent()
            
            for anchor in arView.scene.anchors {
                anchor.children.removeAll(where: { $0 is TextEntity })
            }
            
            switch shapeType {
            case .cube:
                currentEntity = createCube()
            case .sphere:
                currentEntity = createSphere()
            case .pyramid:
                currentEntity = createPyramid()
            case .octagon:
                currentEntity = createOctagon()
            }
            
            let anchorEntity = AnchorEntity(world: [0, 0.1, -0.5])
            if let currentEntity = currentEntity {
                anchorEntity.addChild(currentEntity)
                arView.scene.addAnchor(anchorEntity)
                currentEntity.generateCollisionShapes(recursive: true)
                
                addTextLabel(for: shapeType, to: anchorEntity)
            }
        }

        func addLengthLabel(_ text: String, position: SIMD3<Float>, orientation: simd_quatf, to parent: Entity, fontSize: Float) {
            let labelEntity = TextEntity(text: text, fontSize: fontSize, color: .yellow)
            labelEntity.position = position
            labelEntity.orientation = orientation
            parent.addChild(labelEntity)
        }

        func addTextLabel(for shapeType: ShapeType, to parent: Entity) {
            var description = ""
            var fontSize: Float = 0.02
            
            switch shapeType {
            case .cube:
                let sideLengthCM = sideLength * 100
                let volume = pow(sideLength, 3)
                let formula = "Volume = a³"
                description = """
                Cube
                Side Length: \(String(format: "%.2f", sideLengthCM)) cm
                Volume: \(String(format: "%.3f", volume * 1_000_000)) cm³
                \(formula)
                """
                
                fontSize = Float(sideLength * 0.1)
                
                let sidePosition = SIMD3<Float>(Float(sideLength / 2), 0, 0)
                let sideOrientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
                addLengthLabel("\(String(format: "%.2f", sideLengthCM)) cm", position: sidePosition, orientation: sideOrientation, to: parent, fontSize: fontSize)

            case .sphere:
                let volume = (4.0 / 3.0) * Double.pi * pow(radius, 3)
                description = """
                Sphere
                Radius: \(String(format: "%.2f", radius * 100)) cm
                Volume: \(String(format: "%.3f", volume * 1_000_000)) cm³
                Volume Formula: V = (4/3)πr³
                """
                
                fontSize = Float(radius * 0.1)
                
                let radiusPosition = SIMD3<Float>(Float(radius), 0, 0)
                let radiusOrientation = simd_quatf(angle: 0, axis: [0, 1, 0])
                addLengthLabel("r: \(String(format: "%.2f", radius * 100)) cm", position: radiusPosition, orientation: radiusOrientation, to: parent, fontSize: fontSize)
                
            case .pyramid:
                let baseArea = pow(baseLength, 2)
                let volume = (1.0 / 3.0) * baseArea * height
                description = """
                Pyramid
                Base: \(String(format: "%.2f", baseLength * 100)) cm, Height: \(String(format: "%.2f", height * 100)) cm
                Volume: \(String(format: "%.3f", volume * 1_000_000)) cm³
                Volume Formula: V = (1/3) × Base² × Height
                """
                
                fontSize = Float(max(baseLength, height) * 0.1)
                
                let basePosition = SIMD3<Float>(Float(baseLength / 2), 0, 0)
                let baseOrientation = simd_quatf(angle: 0, axis: [0, 1, 0])
                addLengthLabel("Base: \(String(format: "%.2f", baseLength * 100)) cm", position: basePosition, orientation: baseOrientation, to: parent, fontSize: fontSize)
                
                let heightPosition = SIMD3<Float>(0, Float(height / 2), 0)
                let heightOrientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                addLengthLabel("Height: \(String(format: "%.2f", height * 100)) cm", position: heightPosition, orientation: heightOrientation, to: parent, fontSize: fontSize)
                
            case .octagon:
                let sideLengthInCM = 1.1
                let perimeter = 8 * sideLengthInCM
                let area = 2 * (1 + sqrt(2)) * pow(sideLengthInCM, 2)
                description = """
                Octagon
                Side Length: \(String(format: "%.2f", sideLengthInCM)) cm
                Perimeter: \(String(format: "%.2f", perimeter)) cm
                Area: \(String(format: "%.3f", area)) cm²
                """
                
                fontSize = Float(sideLengthInCM * 0.05)
                
                let octagonSidePosition = SIMD3<Float>(Float(sideLengthInCM / 2), 0, 0)
                let octagonSideOrientation = simd_quatf(angle: 0, axis: [0, 1, 0])
                addLengthLabel("a: \(String(format: "%.2f", sideLengthInCM)) cm", position: octagonSidePosition, orientation: octagonSideOrientation, to: parent, fontSize: fontSize)
            }
            
            let textEntity = TextEntity(text: description, fontSize: 0.02, color: .yellow)
            textEntity.position = [0, 0.25, 0]
            parent.addChild(textEntity)
            self.textEntity = textEntity
        }

        func createCube() -> ModelEntity {
            let mesh = MeshResource.generateBox(size: Float(sideLength))
            let material = SimpleMaterial(color: .blue, isMetallic: false)
            return ModelEntity(mesh: mesh, materials: [material])
        }

        func createSphere() -> ModelEntity {
            let mesh = MeshResource.generateSphere(radius: Float(radius))
            let material = SimpleMaterial(color: .red, isMetallic: false)
            return ModelEntity(mesh: mesh, materials: [material])
        }

        func createPyramid() -> ModelEntity {
            let halfBase = Float(baseLength) / 2.0
            let vertices: [SIMD3<Float>] = [
                SIMD3(0, Float(height), 0),
                SIMD3(-halfBase, 0, -halfBase),
                SIMD3(halfBase, 0, -halfBase),
                SIMD3(halfBase, 0, halfBase),
                SIMD3(-halfBase, 0, halfBase)
            ]
            
            let indices: [UInt32] = [
                0, 1, 2,
                0, 2, 3,
                0, 3, 4,
                0, 4, 1,
                1, 2, 3,
                3, 4, 1
            ]
            
            var descriptor = MeshDescriptor(name: "Pyramid")
            descriptor.positions = MeshBuffers.Positions(vertices)
            descriptor.primitives = .triangles(indices)
            
            let mesh = try! MeshResource.generate(from: [descriptor])
            let material = SimpleMaterial(color: .yellow, isMetallic: false)
            return ModelEntity(mesh: mesh, materials: [material])
        }

        func createOctagon() -> ModelEntity {
            let angleIncrement = (2.0 * Float.pi) / 8.0
            let radius: Float = 0.011
            
            var vertices: [SIMD3<Float>] = []
            for i in 0..<8 {
                let angle = Float(i) * angleIncrement
                let x = radius * cos(angle)
                let y = radius * sin(angle)
                vertices.append(SIMD3(x, y, 0))
            }
            
            vertices.append(SIMD3(0, 0, 0))

            var indices: [UInt32] = []
            for i in 0..<8 {
                indices.append(UInt32(8))
                indices.append(UInt32(i))
                indices.append(UInt32((i + 1) % 8))
            }
            
            var descriptor = MeshDescriptor(name: "Octagon")
            descriptor.positions = MeshBuffers.Positions(vertices)
            descriptor.primitives = .triangles(indices)
            
            let mesh = try! MeshResource.generate(from: [descriptor])
            let material = SimpleMaterial(color: .green, isMetallic: false)
            
            let octagonEntity = ModelEntity(mesh: mesh, materials: [material])
            octagonEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            
            return octagonEntity
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView, let currentEntity = currentEntity else { return }
            let tapLocation = sender.location(in: arView)
            if let tappedEntity = arView.entity(at: tapLocation), tappedEntity == currentEntity {
                let randomColor = UIColor(
                    red: CGFloat.random(in: 0...1),
                    green: CGFloat.random(in: 0...1),
                    blue: CGFloat.random(in: 0...1),
                    alpha: 1.0
                )
                
                let material = SimpleMaterial(color: randomColor, isMetallic: false)
                if let modelEntity = tappedEntity as? ModelEntity {
                    modelEntity.model?.materials = [material]
                    print("Color changed to: \(randomColor)")
                }
            }
        }
        
        @objc func handleRotation(_ sender: UIRotationGestureRecognizer) {
            guard let entity = currentEntity else { return }
            let rotationAngle = Float(sender.rotation)
            if sender.state == .changed || sender.state == .began {
                let rotation = simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
                entity.orientation *= rotation
                sender.rotation = 0
            }
        }

        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            guard let entity = currentEntity else { return }
            
            if sender.state == .began {
                isPinchGestureActive = true
            }
            
            if sender.state == .changed {
                let scale = sender.scale
                entity.scale *= SIMD3<Float>(repeating: Float(scale))
                sender.scale = 1.0
                
                updateBindingsAfterPinch(for: entity)
            }
            
            if sender.state == .ended {
                isPinchGestureActive = false
            }
        }
        
        private func updateBindingsAfterPinch(for entity: ModelEntity) {
            switch selectedShapeBinding?.wrappedValue {
            case .cube:
                sideLengthBinding?.wrappedValue = String(format: "%.2f", Double(entity.scale.x) * 3.0)
            case .sphere:
                radiusBinding?.wrappedValue = String(format: "%.2f", Double(entity.scale.x) * 1.5)
            case .pyramid:
                baseLengthBinding?.wrappedValue = String(format: "%.2f", Double(entity.scale.x) * 3.0)
                heightBinding?.wrappedValue = String(format: "%.2f", Double(entity.scale.y) * 2.0)
            default:
                break
            }
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard frameCounter % frameInterval == 0 else {
                frameCounter += 1
                return
            }
            frameCounter = 1 // Reset the frame counter after performing detection
            
            guard let model = objectDetector?.model else { return }
            
            // Run the request in a background queue
            DispatchQueue.global(qos: .userInitiated).async {
                let requestHandler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage, options: [:])
                let request = VNCoreMLRequest(model: model) { request, error in
                    guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
                    if let firstResult = results.first, let label = firstResult.labels.first {
                        DispatchQueue.main.async {
                            print("Detected shape: \(label.identifier)")
                        }
                    }
                }
                
                do {
                    try requestHandler.perform([request])
                } catch {
                    print("Failed to perform request: \(error.localizedDescription)")
                }
            }
        }


    }
}

// Object Detector for handling YOLOv3 model
class ObjectDetector {
    var model: VNCoreMLModel?
    
    init() {
        if let visionModel = try? VNCoreMLModel(for: YOLOv3().model) {
            self.model = visionModel
        }
    }
}

// Enum to represent different shape types
enum ShapeType {
    case cube, sphere, pyramid, octagon
}

// TextEntity class for displaying shape descriptions
class TextEntity: Entity, HasModel {
    required init(text: String, fontSize: Float = 0.02, color: UIColor = .white) {
        super.init()
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: CGFloat(fontSize)),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        
        let material = SimpleMaterial(color: color, isMetallic: false)
        self.model = ModelComponent(mesh: mesh, materials: [material])
    }
    required init() { super.init() }
}
