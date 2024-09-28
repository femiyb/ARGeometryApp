import SwiftUI
import RealityKit
import ARKit

// Main Content View
struct ContentView: View {
    @State private var selectedShape: ShapeType = .cube // State variable to track selected shape
    
    var body: some View {
        ZStack {
            // AR View
            ARViewContainer(selectedShape: $selectedShape).edgesIgnoringSafeArea(.all)
            
            // Buttons for shape selection
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        selectedShape = .cube
                    }) {
                        Text("Cube")
                            .padding()
                            .background(selectedShape == .cube ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        selectedShape = .sphere
                    }) {
                        Text("Sphere")
                            .padding()
                            .background(selectedShape == .sphere ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        selectedShape = .pyramid
                    }) {
                        Text("Pyramid")
                            .padding()
                            .background(selectedShape == .pyramid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        selectedShape = .octagon
                    }) {
                        Text("Octagon")
                            .padding()
                            .background(selectedShape == .octagon ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
    }
}

// ARView Container to manage AR functionalities
struct ARViewContainer: UIViewRepresentable {
    @Binding var selectedShape: ShapeType // Bind selected shape from ContentView
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Setup AR configuration
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        // Add Gesture Recognizers
        let tapGestureRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGestureRecognizer)
        
        // Add Pinch Gesture Recognizer for Scaling
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        arView.addGestureRecognizer(pinchGestureRecognizer)
        
        // Add Rotation Gesture Recognizer for Rotating
        let rotationGestureRecognizer = UIRotationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRotation(_:)))
        arView.addGestureRecognizer(rotationGestureRecognizer)
        
        // Add Pan Gesture Recognizer for Moving the Shape
        let panGestureRecognizer = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        arView.addGestureRecognizer(panGestureRecognizer)
        
        context.coordinator.arView = arView
        context.coordinator.createShape(ofType: selectedShape) // Create the initial shape
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update the AR view when selected shape changes
        context.coordinator.createShape(ofType: selectedShape)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // Coordinator class to handle gesture events
    class Coordinator: NSObject {
        var arView: ARView?
        var currentEntity: ModelEntity?
        
        // Create the selected shape
        func createShape(ofType shapeType: ShapeType) {
            guard let arView = arView else { return }
            
            // Remove the existing shape if any
            currentEntity?.removeFromParent()
            
            // Create the new shape based on the selected type
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
            
            // Create an anchor and add the shape to it
            let anchorEntity = AnchorEntity(world: [0, 0.1, -0.5])
            if let currentEntity = currentEntity {
                anchorEntity.addChild(currentEntity)
                arView.scene.addAnchor(anchorEntity)
                currentEntity.generateCollisionShapes(recursive: true)
            }
        }
        
        // Create a cube model
        func createCube() -> ModelEntity {
            let mesh = MeshResource.generateBox(size: 0.3)
            let material = SimpleMaterial(color: .blue, isMetallic: false)
            return ModelEntity(mesh: mesh, materials: [material])
        }
        
        // Create a sphere model
        func createSphere() -> ModelEntity {
            let mesh = MeshResource.generateSphere(radius: 0.15)
            let material = SimpleMaterial(color: .red, isMetallic: false)
            return ModelEntity(mesh: mesh, materials: [material])
        }
        
        // Create a pyramid model using custom vertices and indices
        func createPyramid() -> ModelEntity {
            let vertices: [SIMD3<Float>] = [
                SIMD3(0, 0.15, 0),   // Top vertex
                SIMD3(-0.15, 0, -0.15), // Base vertices
                SIMD3(0.15, 0, -0.15),
                SIMD3(0.15, 0, 0.15),
                SIMD3(-0.15, 0, 0.15)
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
            let angleIncrement = (2.0 * Float.pi) / 8.0 // 8 sides for an octagon
            let radius: Float = 0.15
            
            var vertices: [SIMD3<Float>] = []
            for i in 0..<8 {
                let angle = Float(i) * angleIncrement
                let x = radius * cos(angle)
                let y = radius * sin(angle)
                vertices.append(SIMD3(x, y, 0)) // Notice 'y' is used instead of 'z' to make it vertical
            }

            // Add the center point
            vertices.append(SIMD3(0, 0, 0))

            // Defining indices for the triangles
            var indices: [UInt32] = []
            for i in 0..<8 {
                indices.append(UInt32(8))     // Center point index
                indices.append(UInt32(i))     // Current vertex
                indices.append(UInt32((i + 1) % 8)) // Next vertex (wraps around)
            }
            
            var descriptor = MeshDescriptor(name: "Octagon")
            descriptor.positions = MeshBuffers.Positions(vertices)
            descriptor.primitives = .triangles(indices)
            
            let mesh = try! MeshResource.generate(from: [descriptor])
            let material = SimpleMaterial(color: .green, isMetallic: false)
            
            let octagonEntity = ModelEntity(mesh: mesh, materials: [material])

            // Rotate the octagon to be vertical using Euler angles
            octagonEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            
            return octagonEntity
        }

        // Handle tap gesture to change shape color
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView, let currentEntity = currentEntity else { return }
            
            // Detect the tapped location in the ARView
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
                }
            }
        }

        // Handle pinch gesture to scale the shape
        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            guard let entity = currentEntity else { return }
            
            if sender.state == .changed {
                let scale = sender.scale
                entity.scale *= SIMD3<Float>(repeating: Float(scale))
                sender.scale = 1.0 // Reset the scale to avoid compounding
            }
        }

        // Handle rotation gesture to rotate the current shape
        @objc func handleRotation(_ sender: UIRotationGestureRecognizer) {
            guard let entity = currentEntity else { return }
            
            let rotationAngle = Float(sender.rotation)
            
            if sender.state == .changed || sender.state == .began {
                let rotation = simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
                entity.orientation *= rotation
                sender.rotation = 0 // Reset rotation to avoid compounding
            }
        }

        // Handle pan gesture to move the shape
        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
            guard let arView = arView, let entity = currentEntity else { return }
            
            let translation = sender.translation(in: arView)
            
            var position = entity.position(relativeTo: nil)
            let scaleFactor: Float = 0.001 // Adjust sensitivity
            
            // Update entity's position based on pan translation
            position.x += Float(translation.x) * scaleFactor
            position.z += Float(translation.y) * scaleFactor
            
            entity.position = position
            sender.setTranslation(.zero, in: arView) // Reset translation
        }
    }
}

// Enum to represent different shape types
enum ShapeType {
    case cube, sphere, pyramid, octagon
}
