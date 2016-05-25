//
//  FloydWarshall.swift
//  APSP
//
//  Created by Andrew McKnight on 5/5/16.
//  Copyright © 2016 Andrew McKnight. All rights reserved.
//

import Foundation

private typealias Distances = [[Double]]
private typealias Predecessors = [[Int?]]
private typealias StepResult = (distances: Distances, predecessors: Predecessors)

/**
 Encapsulation of the Floyd-Warshall All-Pairs Shortest Paths algorithm, conforming to the APSPAlgorithm protocol.

 - note: In all complexity bounds, `V` is the number of vertices in the graph, and `E` is the number of edges.
 */
public struct FloydWarshall<T>: APSPAlgorithm {

  typealias Q = T
  typealias P = FloydWarshallResult<T>

  /**
   Floyd-Warshall algorithm for computing all-pairs shortest paths in a weighted directed graph.

   - precondition: `graph` must have no negative weight cycles
   - complexity: `Θ(V^3)` time, `Θ(V^2)` space
   - returns a `FloydWarshallResult` struct which can be queried for shortest paths and their total weights
   */
  public static func apply<T>(graph: Graph<T>) -> FloydWarshallResult<T> {

    var previousDistance = constructInitialDistanceMatrix(graph)
    var previousPredecessor = constructInitialPredecessorMatrix(previousDistance)
    for intermediateIdx in 0 ..< graph.vertices.count {
      let nextResult = nextStep(intermediateIdx, previousDistances: previousDistance, previousPredecessors: previousPredecessor, graph: graph)
      previousDistance = nextResult.distances
      previousPredecessor = nextResult.predecessors

//      // uncomment to see each new weight matrix
//      print("  D(\(k)):\n")
//      printMatrix(nextResult.distances)
//
//      // uncomment to see each new predecessor matrix
//      print("  ∏(\(k)):\n")
//      printIntMatrix(nextResult.predecessors)
    }
    return FloydWarshallResult<T>(weights: previousDistance, predecessors: previousPredecessor)

  }

  /**
   For each iteration of `intermediateIdx`, perform the comparison for the dynamic algorith, checking for each pair of start/end vertices, whether a path taken through another vertex produces a shorter path.

   - complexity: `Θ(V^2)` time/space
   - returns: a tuple containing the next distance matrix with weights of currently known shortest paths and the corresponding predecessor matrix
   */
  static private func nextStep<T>(intermediateIdx: Int, previousDistances: Distances, previousPredecessors: Predecessors, graph: Graph<T>) -> StepResult {

    let vertexCount = graph.adjacencyMatrix.count
    var nextDistances = Array(count: vertexCount, repeatedValue: Array(count: vertexCount, repeatedValue: Double.infinity))
    var nextPredecessors = Array(count: vertexCount, repeatedValue: Array<Int?>(count: vertexCount, repeatedValue: nil))

    for fromIdx in 0 ..< vertexCount {
      for toIndex in 0 ..< vertexCount {
//        printMatrix(previousDistances, i: fromIdx, j: toIdx, k: intermediateIdx) // uncomment to see each comparison being made
        let originalPathWeight = previousDistances[fromIdx][toIndex]
        let newPathWeightBefore = previousDistances[fromIdx][intermediateIdx]
        let newPathWeightAfter = previousDistances[intermediateIdx][toIndex]

        let minimum = min(originalPathWeight, newPathWeightBefore + newPathWeightAfter)
        nextDistances[fromIdx][toIndex] = minimum

        var predecessor: Int?
        if originalPathWeight <= newPathWeightBefore + newPathWeightAfter {
          predecessor = previousPredecessors[fromIdx][toIndex]
        } else {
          predecessor = previousPredecessors[intermediateIdx][toIndex]
        }
        nextPredecessors[fromIdx][toIndex] = predecessor
      }
    }
    return (nextDistances, nextPredecessors)

  }

  /** 
   We need to convert the value system in Graph's adjacency matrix to the one we need to perform the algorithm. We need the actual weight between two vertices, or infinity if no edge exists, represented by nil in Graph.adjacencyMatrix. Also set the weight to 0 on the diagonal.
   
   - complexity: `Θ(V^2)` time/space
   - returns: weighted adjacency matrix in form ready for processing with Floyd-Warshall
   */
  static private func constructInitialDistanceMatrix<T>(graph: Graph<T>) -> Distances {

    let vertexCount = graph.adjacencyMatrix.count
    var distances = Array(count: vertexCount, repeatedValue: Array(count: vertexCount, repeatedValue: Double.infinity))

    for fromIdx in 0 ..< vertexCount {
      for toIdx in 0 ..< vertexCount {
        if fromIdx == toIdx {
          distances[fromIdx][toIdx] = 0.0
        } else if let w = graph.adjacencyMatrix[fromIdx][toIdx] {
          distances[fromIdx][toIdx] = w
        }
      }
    }

    return distances

  }

  /**
   Make the initial predecessor index matrix. Initially each value is equal to it's row index, it's "from" index when querying into it.
   
   - complexity: `Θ(V^2)` time/space
  */
  static private func constructInitialPredecessorMatrix(distances: Distances) -> Predecessors {

    let vertexCount = distances.count
    var predecessors = Array(count: vertexCount, repeatedValue: Array<Int?>(count: vertexCount, repeatedValue: nil))

    for fromIdx in 0 ..< vertexCount {
      for toIdx in 0 ..< vertexCount {
        if fromIdx != toIdx && distances[fromIdx][toIdx] < Double.infinity {
          predecessors[fromIdx][toIdx] = fromIdx
        }
      }
    }

    return predecessors

  }

}

/**
 FloydWarshallResult encapsulates the result of the computation, namely the minimized distance adjacency matrix, and the matrix of predecessor indices.
 
 It conforms to the APSPResult procotol which provides methods to retrieve distances and paths between given pairs of start and end nodes.
 */
public struct FloydWarshallResult<T>: APSPResult {

  private var weights: Distances
  private var predecessors: Predecessors

  /**
   - returns: the total weight of the path from a starting vertex to a destination. This value is the minimal connected weight between the two vertices.
   - complexity: `Θ(1)` time/space
   */
  public func distance(fromVertex from: Vertex<T>, toVertex to: Vertex<T>) -> Double? {

    return weights[from.index][to.index]

  }

  /**
   - returns: the reconstructed path from a starting vertex to a destination, as an array containing the data property of each vertex
   - complexity: `Θ(V)` time, `Θ(V^2)` space
   */
  public func path(fromVertex from: Vertex<T>, toVertex to: Vertex<T>, inGraph graph: Graph<T>) -> [T]? {

    if let path = recursePathFrom(predecessors, fromVertex: from, toVertex: to, path: [ to ], inGraph: graph) {
      let pathValues = path.map() { vertex in
        vertex.data
      }
      return pathValues
    }
    return nil

  }

  /**
   The recursive component to rebuilding the shortest path between two vertices using the predecessor graph.

   - returns: the list of predecessors discovered so far
   */
  private func recursePathFrom(predecessors: [[Int?]], fromVertex from: Vertex<T>, toVertex to: Vertex<T>, path: [Vertex<T>], inGraph graph: Graph<T>) -> [Vertex<T>]? {

    if from.index == to.index {
      return [ from, to ]
    }

    if let predecessor = predecessors[from.index][to.index] {
      let predecessorVertex = graph.vertices[predecessor]
      if predecessor == from.index {
        let newPath = [ from, to ]
        return newPath
      } else {
        let buildPath = recursePathFrom(predecessors, fromVertex: from, toVertex: predecessorVertex, path: path, inGraph: graph)
        let newPath = buildPath! + [ to ]
        return newPath
      }
    }

    return nil
    
  }

}