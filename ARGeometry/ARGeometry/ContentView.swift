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

        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinchGestureRecognizer.delegate = context.coordinator // Set the delegate
        arView.addGestureRecognizer(pinchGestureRecognizer)

        let rotationGestureRecognizer = UIRotationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRotation(_:)))
        rotationGestureRecognizer.delegate = context.coordinator // Set the delegate
        arView.addGestureRecognizer(rotationGestureRecognizer)

        /*
        let panGestureRecognizer = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGestureRecognizer.delegate = context.coordinator // Set the delegate
        arView.addGestureRecognizer(panGestureRecognizer) */

        context.coordinator.arView = arView
        context.coordinator.createShape(ofType: selectedShape)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update the AR view when the selected shape changes
        context.coordinator.createShape(ofType: selectedShape)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // Coordinator class to handle gesture events
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var arView: ARView?
        var currentEntity: ModelEntity?
        var textEntity: Entity? // To hold the text label

        // Allow multiple gesture recognizers to work simultaneously
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        // Create the selected shape
        func createShape(ofType shapeType: ShapeType) {
            guard let arView = arView else { return }
            
            // Remove the existing shape and text if any
            currentEntity?.removeFromParent()
            textEntity?.removeFromParent()
            
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
                
                // Add text label above the shape
                addTextLabel(for: shapeType, to: anchorEntity)
            }
        }

        // Create the text label for the shape
        func addTextLabel(for shapeType: ShapeType, to parent: Entity) {
            // Define the text based on the shape type
            let description: String
            switch shapeType {
            case .cube:
                description = "Cube\nSize: 0.3m"
            case .sphere:
                description = "Sphere\nRadius: 0.15m"
            case .pyramid:
                description = "Pyramid\nHeight: 0.15m"
            case .octagon:
                description = "Octagon\nDiameter: 0.3m"
            }
            
            // Create a text entity
            let textEntity = TextEntity(text: description)
            textEntity.position = [0, 0.25, 0] // Position the label above the shape
            
            // Add the text entity to the parent
            parent.addChild(textEntity)
            self.textEntity = textEntity
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
            let angleIncrement = (2.0 * Float.pi) / 8.0
            let radius: Float = 0.15
            
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
        /*
        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
            guard let arView = arView, let entity = currentEntity else { return }
            
            // Check if the pan gesture is just beginning
            if sender.state == .began {
                let touchLocation = sender.location(in: arView)
                if let hitEntity = arView.entity(at: touchLocation), hitEntity == entity {
                    print("Pan gesture started on the entity.")
                } else {
                    print("Pan gesture did not start on the entity. Ignoring...")
                    return
                }
            }
            
            // Update the entity's position if the pan gesture is in progress
            if sender.state == .changed {
                let translation = sender.translation(in: arView)
                
                // Convert the 2D translation to a 3D world position
                var currentPosition = entity.position(relativeTo: nil)
                
                // Adjust translation to control sensitivity
                let xTranslation = Float(translation.x) * 0.001
                let zTranslation = Float(translation.y) * 0.001
                
                // Update entity's position
                currentPosition.x += xTranslation
                currentPosition.z -= zTranslation
                
                entity.position = currentPosition
                
                // Reset the translation to avoid compounding the effect
                sender.setTranslation(.zero, in: arView)
            }
        }*/
    }

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
    required init() {
           super.init()
       }
}

// Enum to represent different shape types
enum ShapeType {
    case cube, sphere, pyramid, octagon
}

