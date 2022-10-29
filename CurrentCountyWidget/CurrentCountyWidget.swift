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
}

struct APIResponse : Decodable {
    var riskLevelInteger: Int
    var riskLevelString: String
    var countyName: String
    var stateName: String
    var lastUpdatedTimestamp: String
    var lastUpdatedString: String
    
    static let placeholderData = APIResponse(
        riskLevelInteger: 0,
        riskLevelString: "Level",
        countyName: "Current County",
        stateName: "State Name",
        lastUpdatedTimestamp: "every Thursday",
        lastUpdatedString: "every Thursday"
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
        Model(date: Date(), riskData: APIResponse.placeholderData, userLocation: CLLocation(), backgroundImage: Image("BackgroundLoading"))
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Model) -> ()) {
        let entry = Model(date: Date(), riskData: APIResponse.placeholderData, userLocation: CLLocation(), backgroundImage: Image("BackgroundLoading"))
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Model>) -> ()) {

        widgetLocationManager.fetchLocation(handler: { location in
            fetchAPIData(userLocation: location, completion: { (modelData) in
                var backgroundImage = Image("BackgroundLoading")
                
                if modelData.riskLevelInteger == 0 {
                    backgroundImage = Image("BackgroundLow")
                } else if modelData.riskLevelInteger == 1 {
                    backgroundImage = Image("BackgroundMedium")
                } else if modelData.riskLevelInteger == 2 {
                    backgroundImage = Image("BackgroundHigh")
                }
                
                let date = Date()
                let data = Model(date: date, riskData: modelData, userLocation: location, backgroundImage: backgroundImage)
                
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
                VStack(alignment: .leading, spacing: 4) {
                    (
                        Text(data.riskData.countyName)
                            .foregroundColor(.white)
                            .font(.system(size: 15, weight: .semibold))
                        +
                        Text("&nbsp;")
                            .foregroundColor(.white)
                            .font(.system(size: 15, weight: .semibold))
                        +
                        Text(Image(systemName: "location.fill"))
                            .foregroundColor(.white)
                            .font(.system(size: 10))
                    )
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(EdgeInsets(top: -3, leading: 0, bottom: 0, trailing: 0))
                    Text(data.riskData.riskLevelString)
                        .foregroundColor(.white)
                        .font(.title)
                    Spacer()
                    Text("Last updated")
                        .foregroundColor(.white)
                        .font(.system(size: 13, weight: .regular))
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: -3, trailing: 0))
                        .opacity(0.7)
                    Text(data.riskData.lastUpdatedString)
                        .foregroundColor(.white)
                        .font(.system(size: 13, weight: .regular))
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: -3, trailing: 0))
                        .opacity(0.7)
                }.padding(16)
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
        ZStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current County")
                        .foregroundColor(.white)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(EdgeInsets(top: -3, leading: 0, bottom: 0, trailing: 0))
                    Text("Level")
                        .foregroundColor(.white)
                        .font(.title)
                    Spacer()
                    Text("Updated every Thursday")
                        .foregroundColor(.white)
                        .font(.system(size: 13, weight: .regular))
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: -3, trailing: 0))
                }.padding(16)
                Spacer()
            }
        }.background(
            Color(.gray)
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
