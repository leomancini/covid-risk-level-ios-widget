//
//  CurrentCountyWidget.swift
//  CurrentCountyWidget
//
//  Created by Leo Mancini on 8/21/22.
//

import WidgetKit
import SwiftUI
import Intents
import CoreLocation

struct Model: TimelineEntry {
    var date: Date
    var riskData: APIResponse
    var userLocation: CLLocation
    var backgroundColor: Color
    var riskLevelString: String
}

struct APIResponse : Decodable {
    var CCL_community_burden_level_integer: String
    var County: String
    var State_name: String
    var CCL_report_date: String
    
    static let placeholderData = APIResponse(
        CCL_community_burden_level_integer: "0",
        County: "Test",
        State_name: "Test",
        CCL_report_date: "Test"
    )
}

func fetchAPIData(userLocation: CLLocation, completion: @escaping (APIResponse) -> ()) {
    let latitude = String(userLocation.coordinate.latitude)
    let longitude = String(userLocation.coordinate.longitude)
    
    let url = String(format: "https://jndaditnce62h556zs2k5q3kqu0hlvjr.lambda-url.us-east-1.on.aws/?location=%@,%@", arguments: [latitude, longitude])
    
    let session = URLSession(configuration: .default)
    
    session.dataTask(with: URL(string: url)!) { (data, _, err) in
        if err != nil {
            print(err!)
            return
        }
        
        do {
            let jsonData = try
            JSONDecoder().decode(APIResponse.self, from: data!)
            completion(jsonData)
        } catch {
            print(err!)
        }
    }.resume()
}

struct Provider: IntentTimelineProvider {
    var widgetLocationManager = WidgetLocationManager()

    func placeholder(in context: Context) -> Model {
        Model(date: Date(), riskData: APIResponse.placeholderData, userLocation: CLLocation(), backgroundColor: Color(.white), riskLevelString: "Loading...")
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Model) -> ()) {
        let entry = Model(date: Date(), riskData: APIResponse.placeholderData, userLocation: CLLocation(), backgroundColor: Color(.white), riskLevelString: "Loading...")
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Model>) -> ()) {

        widgetLocationManager.fetchLocation(handler: { location in
            fetchAPIData(userLocation: location, completion: { (modelData) in
                var backgroundColor = Color(.white)
                var riskLevelString = "Loading..."
                
                if modelData.CCL_community_burden_level_integer == "0" {
                    backgroundColor = Color(.green)
                    riskLevelString = "Low"
                } else if modelData.CCL_community_burden_level_integer == "1" {
                    backgroundColor = Color(.orange)
                    riskLevelString = "Medium"
                } else if modelData.CCL_community_burden_level_integer == "2" {
                    backgroundColor = Color(.red)
                    riskLevelString = "High"
                }
                
                let date = Date()
                let data = Model(date: date, riskData: modelData, userLocation: location, backgroundColor: backgroundColor, riskLevelString: riskLevelString)
                
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: date)
                
                let timeline = Timeline(entries: [data], policy: .after(nextUpdate!))
                                        
                completion(timeline)
            })
        })
    }
}

class WidgetLocationManager: NSObject, CLLocationManagerDelegate {
    var locationManager: CLLocationManager?
    private var handler: ((CLLocation) -> Void)?

    override init() {
        super.init()
        DispatchQueue.main.async {
            self.locationManager = CLLocationManager()
            self.locationManager!.delegate = self
            if self.locationManager!.authorizationStatus == .notDetermined {
                self.locationManager!.requestWhenInUseAuthorization()
            }
        }
    }
    
    func fetchLocation(handler: @escaping (CLLocation) -> Void) {
        self.handler = handler
        self.locationManager!.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.handler!(locations.last!)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
}

struct CurrentCountyWidgetEntryView : View {
    var data: Model
    
    var body: some View {
        ZStack {
            data.backgroundColor
            VStack {
                Text(data.riskData.County)
                Text(data.riskLevelString)
            }
        }
    }
}

@main
struct CurrentCountyWidget: Widget {
    let kind: String = "CurrentCountyWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { data in
            CurrentCountyWidgetEntryView(data: data)
        }
        .configurationDisplayName("Covid Risk Level")
        .description("Shows the CDC Covid risk level in the county you are currently in.")
    }
}

struct CurrentCountyWidgetPreviews: PreviewProvider {
    static var previews: some View {
        CurrentCountyWidgetEntryView(data: Model(date: Date(), riskData: APIResponse.placeholderData, userLocation: CLLocation(), backgroundColor: Color(.white), riskLevelString: "Loading..."))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
