//
//  ContentView.swift
//  MapLookAroundSample
//
//  Created by cano on 2022/10/16.
//

import SwiftUI
import MapKit

// マップ設定
class MapSettings: ObservableObject {
    @Published var mapType = 0
    @Published var showElevation = 0
    @Published var showEmphasisStyle = 0
}

// MKLookAroundSceneを参照するためのオブジェクト
class LookAroundLoader: ObservableObject  {
    @Published var scene: MKLookAroundScene?
}

// MapViewのデリゲート
class MapViewCoordinator: NSObject, MKMapViewDelegate {
    var mapView: MapView
        
    init(_ control: MapView) {
        self.mapView = control
    }

    // アノテーション生成
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let markerView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "LookAroundPlace")
        markerView.animatesWhenAdded = true
        markerView.titleVisibility = .adaptive
        return markerView
    }
    
    // アノテーション選択時
    func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
        searchLookAround(from: annotation)
    }
    
    // アノテーションの選択を解除
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        // MKLookAroundSceneを空にする
        self.mapView.lookAroundLoader.scene = nil
    }
    
    // アノテーションからMKAnnotationを検索
    func searchLookAround(from annotation: MKAnnotation) {
        let sceneRequest = MKLookAroundSceneRequest(coordinate: annotation.coordinate)
        sceneRequest.getSceneWithCompletionHandler { [unowned self] scene, error in
            if let error{
                print("Not Found Error", error)
            } else if let scene{
                // MKLookAroundSceneがあればセットする
                self.mapView.lookAroundLoader.scene = scene
            }
        }
    }
}

// MKMapViewをSwiftUIで使えるように
struct MapView: UIViewRepresentable {
    // 吉祥寺駅
    var mapRegion = MKCoordinateRegion(center:
                                                CLLocationCoordinate2D(latitude: 35.7023137, longitude: 139.5803228),
                                               span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003))
    
    @EnvironmentObject var mapSettings: MapSettings
    @EnvironmentObject var lookAroundLoader: LookAroundLoader
    
    // UI初期化処理
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.region = mapRegion
        // 地図内のスポットを選択できるように
        mapView.selectableMapFeatures = [.physicalFeatures,.pointsOfInterest,.territories]
        // delegate設定
        mapView.delegate = context.coordinator
        return mapView
    }
    
    // UI更新処理
    func updateUIView(_ uiView: MKMapView, context: Context) {
        updateMapType(uiView)
    }
    
    // MKMapView種別設定
    private func updateMapType(_ uiView: MKMapView) {
        switch self.mapSettings.mapType {
        case 0:
            uiView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: elevationStyle(), emphasisStyle: emphasisStyle())
        case 1:
            uiView.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: elevationStyle())
        case 2:
            uiView.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: elevationStyle())
        default:
            break
        }
    }
    
    private func elevationStyle() -> MKMapConfiguration.ElevationStyle {
        if mapSettings.showElevation == 0 {
            return MKMapConfiguration.ElevationStyle.realistic
        } else {
            return MKMapConfiguration.ElevationStyle.flat
        }
    }
    
    private func emphasisStyle() -> MKStandardMapConfiguration.EmphasisStyle {
        if mapSettings.showEmphasisStyle == 0 {
            return MKStandardMapConfiguration.EmphasisStyle.default
        } else {
            return MKStandardMapConfiguration.EmphasisStyle.muted
        }
    }
    
    // デリゲート設定
    func makeCoordinator() -> MapViewCoordinator{
         MapViewCoordinator(self)
    }
}

// MKLookAroundViewControllerをSwiftUIで使えるように
struct LookAroundView: UIViewRepresentable {
    @EnvironmentObject var lookAroundLoader: LookAroundLoader
    let view = MKLookAroundViewController()
    
    func makeUIView(context: Context) -> UIView {
        return view.view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // MKLookAroundViewがあれば表示する
        if let scene = lookAroundLoader.scene {
            view.scene = scene
        }
    }
}

struct ContentView: View {
    @ObservedObject var mapSettings = MapSettings()
    @State var mapType          = 0
    @State var showElevation    = 0
    @State var showEmphasis     = 0
    
    @ObservedObject var lookAroundLoader = LookAroundLoader()
    
    var body: some View {
        ZStack {
            // MapView配置
            MapView().edgesIgnoringSafeArea(.all)
                     .environmentObject(mapSettings)
                     .environmentObject(lookAroundLoader)
        }.overlay(alignment: .bottom) {
            VStack {
                // MKLookAroundViewがあれば表示する
                if lookAroundLoader.scene != nil {
                    HStack {
                        LookAroundView().environmentObject(lookAroundLoader)
                            .frame(width: 160).frame(height: 120)
                        Spacer()
                    }.padding([.leading, .top], 20)
                }
                // 地図の種別設定
                Picker("Map Type", selection: $mapType) {
                    Text("Standard").tag(0)
                    Text("Hybrid").tag(1)
                    Text("Image").tag(2)
                }.pickerStyle(SegmentedPickerStyle())
                    .onChange(of: mapType) {
                        mapSettings.mapType = $0
                    }.padding([.top, .leading, .trailing], 16)
                
                // 標高スタイル
                // リアル（既定）、フラット
                Picker("Map Elevation", selection: $showElevation) {
                    Text("Realistic").tag(0)
                    Text("Flat").tag(1)
                }.pickerStyle(SegmentedPickerStyle())
                    .onChange(of: showElevation) {
                        mapSettings.showElevation = $0
                }.padding([.leading, .trailing], 16)
                
                // 現実世界にある消火栓や道路、建物などをベクター データ化した個々の地物をフィーチャといいます
                // そのフィーチャを強調（既定）、ミュートするかの設定
                Picker("Map Elevation", selection: $showEmphasis) {
                    Text("Default").tag(0)
                    Text("Muted").tag(1)
                }.pickerStyle(SegmentedPickerStyle())
                    .onChange(of: showEmphasis) {
                        mapSettings.showEmphasisStyle = $0
                }.padding([.leading, .trailing], 16)
            }.background(.gray)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
