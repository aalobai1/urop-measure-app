//
//  ViewController.swift
//  AMMeasure
//
//  Created by Bhat, Adithya H on 04/04/19.
//

import UIKit
import ARKit

class AreaViewController: MeasureViewController {
    
    enum MeasureState {
        case lengthCalc
        case breadthCalc
    }
    
    struct FloorRect {
        var length: CGFloat
        var breadth: CGFloat
        var area: CGFloat {
            get {
                return length * breadth
            }
        }
    }
    
    var floorRect = FloorRect(length: 0, breadth: 0)
    var grids = [Grid]()
    var lengthNodes = NSMutableArray()
    var breadthNodes = NSMutableArray()
    var lineNodes = NSMutableArray()
    var currentState: MeasureState = MeasureState.lengthCalc
    
    var allPointNodes: [Any] {
        get {
            return lengthNodes as! [Any] + breadthNodes
        }
    }
    var nodeColor: UIColor {
        get {
            return nodeColor(forState: currentState, alphaComponent: 0.7)
        }
    }
    
    @IBOutlet weak var areaLabel: UILabel!
    @IBOutlet weak var breadthLabel: UILabel!
    @IBOutlet weak var lengthLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.debugOptions = ARSCNDebugOptions.showFeaturePoints
        lengthLabel.textColor = nodeColor(forState: .lengthCalc, alphaComponent: 1)
        breadthLabel.textColor = nodeColor(forState: .breadthCalc, alphaComponent: 1)
    }
    
    //MARK: - Private helper methods
    
    private func nodeColor(forState state: MeasureState, alphaComponent: CGFloat) -> UIColor {
        switch state {
        case .lengthCalc:
            return UIColor.red.withAlphaComponent(alphaComponent)
        case .breadthCalc:
            return UIColor.green.withAlphaComponent(alphaComponent)
        }
    }
    
    
    private func nodesList(forState state: MeasureState) -> NSMutableArray {
        switch state {
        case .lengthCalc:
            return lengthNodes
        case .breadthCalc:
            return breadthNodes
        }
    }
    
    func clearScene() {
        removeNodes(fromNodeList: nodesList(forState: .lengthCalc))
        removeNodes(fromNodeList: nodesList(forState: .breadthCalc))
        removeNodes(fromNodeList: lineNodes)
    }
    
    private func resetMeasurement() {
        clearScene()
        floorRect = FloorRect(length: 0, breadth: 0)
        currentState = .lengthCalc
        lengthLabel.text = "--"
        breadthLabel.text = "--"
        areaLabel.text = "--"
    }
    
    
    //MARK: - IBActions
    
    @IBAction func addPoint(_ sender: UIButton) {
        let pointLocation = view.convert(screenCenterPoint, to: sceneView)
        guard let hitResultPosition = sceneView.hitResult(forPoint: pointLocation)  else {
            return
        }
        
        //To prevent multiple taps
        sender.isUserInteractionEnabled = false
        defer {
            sender.isUserInteractionEnabled = true
        }
        
        
        if allPointNodes.count >= 4 {
            resetMeasurement()
        }
        
        let nodes = nodesList(forState: currentState)
        
        let sphere = SCNSphere(color: nodeColor, radius: nodeRadius)
        let node = SCNNode(geometry: sphere)
        node.position = hitResultPosition
        sceneView.scene.rootNode.addChildNode(node)
        
        // Add the Sphere to the list.
        nodes.add(node)
        
        if nodes.count == 1 {
            
            //Add a realtime line
            let realTimeLine = LineNode(from: hitResultPosition,
                                        to: hitResultPosition,
                                        lineColor: nodeColor,
                                        lineWidth: lineWidth)
            realTimeLine.name = realTimeLineName
            realTimeLineNode = realTimeLine
            sceneView.scene.rootNode.addChildNode(realTimeLine)
            
        } else if nodes.count == 2 {
            let startNode = nodes[0] as! SCNNode
            let endNode = nodes[1]  as! SCNNode
            
            
            
            // Create a node line between the nodes
            let measureLine = LineNode(from: startNode.position,
                                       to: endNode.position,
                                       lineColor: nodeColor,
                                       lineWidth: lineWidth)
            sceneView.scene.rootNode.addChildNode(measureLine)
            lineNodes.add(measureLine)
            
            //calc distance
            let distance = sceneView.distance(betweenPoints: startNode.position, point2: endNode.position)
            
            //Remove realtime line node
            realTimeLineNode?.removeFromParentNode()
            realTimeLineNode = nil
            
            //Change state
            switch currentState {
            case .lengthCalc:
                floorRect.length = distance
                currentState = .breadthCalc
                lengthLabel.text = String(format: "%.2fm", distance)
            case .breadthCalc:
                floorRect.breadth = distance
                breadthLabel.text = String(format: "%.2fm", distance)
                areaLabel.text = String(format: "%.2fm", floorRect.area)
                
            }
        }
    }
}

extension AreaViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dotNodes = allPointNodes as! [SCNNode]
        if dotNodes.count > 0, let currentCameraPosition = self.sceneView.pointOfView {
            updateScaleFromCameraForNodes(dotNodes, fromPointOfView: currentCameraPosition)
        }
        
        //Update realtime line node
        if let realTimeLineNode = self.realTimeLineNode,
            let hitResultPosition = sceneView.hitResult(forPoint: screenCenterPoint),
            let startNode = self.nodesList(forState: self.currentState).firstObject as? SCNNode {
            realTimeLineNode.updateNode(vectorA: startNode.position, vectorB: hitResultPosition, color: .gray)
            
            let distance = sceneView.distance(betweenPoints: startNode.position, point2: hitResultPosition)
            let label = currentState == .lengthCalc ? lengthLabel : breadthLabel
            DispatchQueue.main.async { [unowned self] in
                label?.text = String(format: "%.2fm", distance)
                label?.textColor = self.nodeColor
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        var planeAnchor: ARPlaneAnchor
        if #available(iOS 11.3, *) {
            guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else { return }
        } else {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        }
           let grid = Grid(anchor: planeAnchor)
           self.grids.append(grid)
           node.addChildNode(grid)
        
        
//        // Place content only for anchors found by plane detection.
//        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
//
//        // Create a custom object to visualize the plane geometry and extent.
//        let plane = Plane(anchor: planeAnchor, in: sceneView)
//
//        // Add the visualization to the ARKit-managed node so that it tracks
//        // changes in the plane anchor as plane estimation continues.
//        node.addChildNode(plane)
        
//        if allPointNodes.count == 4 {
//            // 1
//            guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
//
//            // 2
//            let width = CGFloat(planeAnchor.extent.x)
//            let height = CGFloat(planeAnchor.extent.z)
//            let plane = SCNPlane(width: width, height: height)
//
//            // 3
//            plane.materials.first?.diffuse.contents = UIColor.blue
//
//            // 4
//            let planeNode = SCNNode(geometry: plane)
//
//            // 5
//            let x = CGFloat(planeAnchor.center.x)
//            let y = CGFloat(planeAnchor.center.y)
//            let z = CGFloat(planeAnchor.center.z)
//            planeNode.position = SCNVector3(x,y,z)
//            planeNode.eulerAngles.x = -.pi / 2
//
//            // 6
//            node.addChildNode(planeNode)
//        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        var planeAnchor: ARPlaneAnchor
        if #available(iOS 11.3, *) {
            guard let foundAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else { return }
            planeAnchor = foundAnchor
        } else {
            guard let foundAnchor = anchor as? ARPlaneAnchor else { return } // SET THE ALIGNMENT
            planeAnchor = foundAnchor
        }
        
        let grid = self.grids.filter { grid in
            return grid.anchor.identifier == planeAnchor.identifier
            }.first

        guard let foundGrid = grid else {
            return
        }

        foundGrid.update(anchor: planeAnchor)
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            break
        default:
            break
        }
    }
    
}
