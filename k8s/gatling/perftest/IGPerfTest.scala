package perftest

import io.gatling.core.Predef._
import io.gatling.http.Predef._
import scala.concurrent.duration._

class IGPerfTest extends Simulation {

  val httpConf = http
    .baseURL("http://openig") // Since gatling is running in k8s, we can use the service name to find OpenIG
    .acceptHeader("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8") // Here are the common headers
    .doNotTrackHeader("1")
    .acceptLanguageHeader("en-US,en;q=0.5")
    .acceptEncodingHeader("gzip, deflate")
    .userAgentHeader("Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:16.0) Gecko/20100101 Firefox/16.0")

  val headers_10 = Map("Content-Type" -> "application/x-www-form-urlencoded") // Note the headers specific to a given request

  val scn = scenario("Basic OpenIG scenario") // A scenario is a chain of requests and pauses
    .exec(http("Root URL")
    .get("/"))
    .pause(1) // Note that Gatling has recorded real time pauses
    .exec(http("Hello Page")
    .get("/hello"))
    .pause(2)
    .exec(http("Throttle page")
    .get("/simplethrottle"))


//    .exec(http("request_10") // Here's an example of a POST request
//      .post("/computers")
//      .headers(headers_10)
//      .formParam("name", "Beautiful Computer") // Note the triple double quotes: used in Scala for protecting a whole chain of characters (no need for backslash)
//      .formParam("introduced", "2012-05-30")
//      .formParam("discontinued", "")
//      .formParam("company", "37"))

  setUp(scn.inject(atOnceUsers(100)).protocols(httpConf))
}
