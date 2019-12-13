//
//  ContentView.swift
//  LoftgaediApp
//
//  Created by Solberg Audunsson on 12/12/2019.
//  Copyright © 2019 Solberg Audunsson. All rights reserved.
//

import SwiftUI
import CoreLocation
import Combine
import MapKit

class StationApi: NSObject, ObservableObject {

    @Published var locationStatus: CLAuthorizationStatus? {
        willSet {
            objectWillChange.send()
        }
    }

    @Published var lastLocation: CLLocation? {
        willSet {
            objectWillChange.send()
            self.reorder()
        }
    }
    
    @Published var stations: [Station] {
        willSet {
            objectWillChange.send()
        }
    }

    override init() {
        self.stations = []
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
        self.fetchStations()
        
    }
    
    func reorder() {
        if(self.lastLocation != nil) {
            self.stations.sort(by: { $0.distance(to: self.lastLocation!) < $1.distance(to: self.lastLocation!) })
        }
    }
    
    func fetchStations() {
        let url = URL(string: "https://loftgaedi.onrender.com/")!
        URLSession.shared.dataTask(with: url) {(data, response, error) in
            do {
                if let d = data {
                    let decodedLists = try JSONDecoder().decode([Station].self, from: d)
                    DispatchQueue.main.async {
                        self.stations = decodedLists
                        self.reorder()
                    }
                } else {
                    print ("No data")
                }
            } catch {
                print (error)
            }
        }.resume()
    }

    var statusString: String {
        guard let status = locationStatus else {
            return "unknown"
        }

        switch status {
        case .notDetermined: return "notDetermined"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        case .authorizedAlways: return "authorizedAlways"
        case .restricted: return "restricted"
        case .denied: return "denied"
        default: return "unknown"
        }

    }

    let objectWillChange = PassthroughSubject<Void, Never>()

    private let locationManager = CLLocationManager()
}

extension StationApi: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.locationStatus = status
        print(#function, statusString)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.lastLocation = location
        print(#function, location)
    }

}

struct StationStat {
    var id: String
    var value: String
}

struct Station: Decodable, Identifiable {
    
    public var id: Int
    public var name: String
    public var comment: String?
    public var status: Int
    public var latitude: String
    public var longitude: String
    public var measurements: [String:String?]
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case comment = "comment"
        case status = "status"
        case latitude = "latitude"
        case longitude = "longitude"
        case measurements = "measurements"
    }
    
    func stats() -> [StationStat] {
        var _stats: [StationStat] = []
        for (k, v) in measurements {
            _stats.append(StationStat(id: k, value: v ?? ""))
        }
        return _stats
    }
    
    func location() -> CLLocation {
        return CLLocation(
            latitude: CLLocationDegrees(Double(self.latitude) ?? 0.0),
            longitude: CLLocationDegrees(Double(self.longitude) ?? 0.0)
        )
    }
    
    func distance(to location: CLLocation) -> CLLocationDistance {
        return location.distance(from: self.location())
    }
    
}

func getColorFromRGBInt(red: Int, green: Int, blue: Int) -> Color {
    return Color(
        red: Double(red) / 255,
        green: Double(green) / 255,
        blue: Double(blue) / 255,
        opacity: 1.0
    )
}

private func getColor(status: Int) -> Color {
    let color: Color
    switch status {
    case 1: color = getColorFromRGBInt(red: 58,  green: 183, blue: 52)  // Mjög gott
    case 2: color = getColorFromRGBInt(red: 163, green: 199, blue: 94)  // Gott
    case 3: color = getColorFromRGBInt(red: 239, green: 239, blue: 51)  // Miðlungs
    case 4: color = getColorFromRGBInt(red: 226, green: 121, blue: 27)  // Slæmt
    case 5: color = getColorFromRGBInt(red: 241, green: 56,  blue: 56)  // Mjög slæmt
    default: color = Color.black
    }
    return color
}


struct MapView: UIViewRepresentable {
    
    var center: CLLocation
    
    func makeUIView(context: Context) -> MKMapView {
        MKMapView(frame: .zero)
    }
    
    func updateUIView(_ view: MKMapView, context: Context) {
        let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        let region = MKCoordinateRegion(center: center.coordinate, span: span)
        view.setRegion(region, animated: true)
        let pin = MKPointAnnotation()
        pin.coordinate = center.coordinate
        view.addAnnotation(pin)
    }
    
}

private func getStatLabel(s: String) -> String {
    switch s {
    case "pm10": return "PM₁₀"
    case "no2": return "NO₂"
    case "so2": return "SO₂"
    case "h2s": return "H₂S"
    case "co": return "CO"
    case "pm1": return "PM1"
    case "pm25": return "PM2.5"
    case "humidity": return "Raki %"
    case "pressure": return "Loftþrýstingur"
    case "wind": return "Vindhraði"
    case "wind_max": return "Vindhraði hámark"
    case "vector": return "Vindátt"
    case "temperature": return "Hiti °C"
    default: return s
    }
}

struct StationDetail: View {
    var station: Station
    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                HStack {
                    Text("Gögn frá Umhverfisstofnun")
                        .font(.subheadline)
                    Spacer()
                    Text("www.loftgaedi.is")
                        .font(.subheadline)
                        .fontWeight(.light)
                        .foregroundColor(Color.gray)
                }
                MapView(center: station.location()).frame(height: 230)
            }
            .padding()
            List(station.stats(), id: \.id) { stat in
                HStack {
                    Text(getStatLabel(s: stat.id)).fontWeight(.bold)
                    Spacer()
                    Text(stat.value)
                }
            }
            Spacer()
            .navigationBarTitle(
                Text(station.name)
                    .font(.title)
                    .fontWeight(.bold)
            )
            
        }
    }
}

struct StationDetail_Preview: PreviewProvider {
    static var previews: some View {
        StationDetail(station: Station(
                id: 1,
                name: "Test",
                comment: nil,
                status: 1,
                latitude: "0.1",
                longitude: "0.1",
                measurements: [:]
            )
        )
    }
}


struct StationRow: View {
    var ID:Int
    var status:Int
    var name:String
    var comment:String = ""
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name).font(.headline)
                Text(comment).font(.caption)
            }
            Spacer()
            Circle()
                .fill(getColor(status: status))
                .frame(width: 18, height: 18)
        }
    }
}

struct ContentView: View {
    
    @ObservedObject var api = StationApi()
    
    var body: some View {
        NavigationView {
            List(api.stations) { station in
                NavigationLink(destination: StationDetail(station: station)) {
                    StationRow(
                        ID: station.id,
                        status: station.status,
                        name: station.name,
                        comment: station.comment ?? ""
                    )
                }
            }.navigationBarTitle(
                Text("Loftgæði")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
