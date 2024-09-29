import SwiftUI
import RealityKit
import ARKit

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
        context.coordinator.createShape(ofType: selectedShape) // Create the initial shape
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Convert text input to numeric values in cm, then to meters by dividing by 100
        context.coordinator.sideLength = (Double(sideLength) ?? 3) / 100.0
        context.coordinator.radius = (Double(radius) ?? 1.5) / 100.0
        context.coordinator.baseLength = (Double(baseLength) ?? 3) / 100.0
        context.coordinator.height = (Double(height) ?? 2) / 100.0
        
        context.coordinator.createShape(ofType: selectedShape)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // Coordinator class to handle gesture events
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var arView: ARView?
        var currentEntity: ModelEntity?
        var textEntity: Entity?
        
        var sideLength: Double = 0.03
        var radius: Double = 0.015
        var baseLength: Double = 0.03
        var height: Double = 0.02
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func createShape(ofType shapeType: ShapeType) {
            guard let arView = arView else { return }
            
            // Remove existing entities
            currentEntity?.removeFromParent()
            textEntity?.removeFromParent()
            
            // Create the new shape
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
                
                // Add text label above the shape
                addTextLabel(for: shapeType, to: anchorEntity)
            }
        }

        func addTextLabel(for shapeType: ShapeType, to parent: Entity) {
            let description: String
            switch shapeType {
            case .cube:
                let volume = pow(sideLength, 3)
                description = """
                Cube
                Side: \(sideLength * 100) cm
                Volume: \(String(format: "%.3f", volume * 1_000_000)) cm³
                """
                
            case .sphere:
                let volume = (4.0 / 3.0) * Double.pi * pow(radius, 3)
                description = """
                Sphere
                Radius: \(radius * 100) cm
                Volume: \(String(format: "%.3f", volume * 1_000_000)) cm³
                """
                
            case .pyramid:
                let baseArea = pow(baseLength, 2)
                let volume = (1.0 / 3.0) * baseArea * height
                description = """
                Pyramid
                Base: \(baseLength * 100) cm, Height: \(height * 100) cm
                Volume: \(String(format: "%.3f", volume * 1_000_000)) cm³
                """
                
            case .octagon:
                let sideLengthInCM = 1.1 // Side length now set to 1.1 cm by default
                let perimeter = 8 * sideLengthInCM
                let area = 2 * (1 + sqrt(2)) * pow(sideLengthInCM, 2)
                description = """
                Octagon
                Side Length: \(sideLengthInCM) cm
                Perimeter: \(String(format: "%.2f", perimeter)) cm
                Area: \(String(format: "%.3f", area)) cm²
                """
            }
            
            let textEntity = TextEntity(text: description)
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

        // Create a pyramid model using updated base length and height in cm
        func createPyramid() -> ModelEntity {
            let halfBase = Float(baseLength) / 2.0
            let vertices: [SIMD3<Float>] = [
                SIMD3(0, Float(height), 0),   // Top vertex
                SIMD3(-halfBase, 0, -halfBase), // Base vertices
                SIMD3(halfBase, 0, -halfBase),
                SIMD3(halfBase, 0, halfBase),
                SIMD3(-halfBase, 0, halfBase)
            ]
            
            let indices: [UInt32] = [
                0, 1, 2,   // Side triangles
                0, 2, 3,
                0, 3, 4,
                0, 4, 1,
                1, 2, 3,   // Base square
                3, 4, 1
            ]
            
            var descriptor = MeshDescriptor(name: "Pyramid")
            descriptor.positions = MeshBuffers.Positions(vertices)
            descriptor.primitives = .triangles(indices)
            
            let mesh = try! MeshResource.generate(from: [descriptor])
            let material = SimpleMaterial(color: .yellow, isMetallic: false)
            return ModelEntity(mesh: mesh, materials: [material])
        }

        // Create a vertically oriented octagon model using custom vertices and indices
        func createOctagon() -> ModelEntity {
            let angleIncrement = (2.0 * Float.pi) / 8.0
            let radius: Float = 0.011 // 1.1 cm in meters
            
            var vertices: [SIMD3<Float>] = []
            for i in 0..<8 {
                let angle = Float(i) * angleIncrement
                let x = radius * cos(angle)
                let y = radius * sin(angle)
                vertices.append(SIMD3(x, y, 0))
            }
            
            vertices.append(SIMD3(0, 0, 0))  // Center point

            var indices: [UInt32] = []
            for i in 0..<8 {
                indices.append(UInt32(8))    // Center point index
                indices.append(UInt32(i))    // Current vertex
                indices.append(UInt32((i + 1) % 8)) // Next vertex
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

        // Handle tap gesture to change shape color
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
        
        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            guard let entity = currentEntity else { return }
            if sender.state == .changed {
                let scale = sender.scale
                entity.scale *= SIMD3<Float>(repeating: Float(scale))
                sender.scale = 1.0
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
