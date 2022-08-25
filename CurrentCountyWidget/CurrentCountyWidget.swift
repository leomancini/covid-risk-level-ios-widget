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
    var backgroundImage: Image
    var riskLevelString: String
}

struct APIResponse : Decodable {
    var CCL_community_burden_level_integer: String
    var County: String
    var State_name: String
    var CCL_report_date: String
    
    static let placeholderData = APIResponse(
        CCL_community_burden_level_integer: "Level",
        County: "County Name",
        State_name: "State Name",
        CCL_report_date: "Last Updated Time"
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
        Model(date: Date(), riskData: APIResponse.placeholderData, userLocation: CLLocation(), backgroundImage: Image("BackgroundLoading"), riskLevelString: "Loading...")
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Model) -> ()) {
        let entry = Model(date: Date(), riskData: APIResponse.placeholderData, userLocation: CLLocation(), backgroundImage: Image("BackgroundLoading"), riskLevelString: "Loading...")
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Model>) -> ()) {

        widgetLocationManager.fetchLocation(handler: { location in
            fetchAPIData(userLocation: location, completion: { (modelData) in
                var backgroundImage = Image("BackgroundLoading")
                var riskLevelString = "Loading..."
                
                if modelData.CCL_community_burden_level_integer == "0" {
                    backgroundImage = Image("BackgroundLow")
                    riskLevelString = "Low"
                } else if modelData.CCL_community_burden_level_integer == "1" {
                    backgroundImage = Image("BackgroundMedium")
                    riskLevelString = "Medium"
                } else if modelData.CCL_community_burden_level_integer == "2" {
                    backgroundImage = Image("BackgroundHigh")
                    riskLevelString = "High"
                }
                
                let date = Date()
                let data = Model(date: date, riskData: modelData, userLocation: location, backgroundImage: backgroundImage, riskLevelString: riskLevelString)
                
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
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(data.riskData.County)
                        .foregroundColor(.white)
                        .font(.headline.bold())
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(data.riskLevelString)
                        .foregroundColor(.white)
                        .font(.title.bold())
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    Spacer()
                    Text(data.riskData.CCL_report_date)
                        .foregroundColor(.white)
                        .opacity(0.5)
                }.padding(20)
                Spacer()
            }
        }.background(
            data.backgroundImage
                .resizable()
                .edgesIgnoringSafeArea(.all)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        )
    }
}

@main
struct CurrentCountyWidget: Widget {
    let kind: String = "CurrentCountyWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { data in
            CurrentCountyWidgetEntryView(data: data)
        }
        .configurationDisplayName("Covid Community Level")
        .description("Shows the CDC community level in the county you are currently in.")
    }
}

struct CurrentCountyWidgetPreviews: PreviewProvider {
    static var previews: some View {
        Text("Loading...")
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
