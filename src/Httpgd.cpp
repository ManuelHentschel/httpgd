// [[Rcpp::plugins("cpp11")]]

#include <Rcpp.h>
#include <R_ext/GraphicsEngine.h>
#include <R_ext/GraphicsDevice.h>

#include <vector>
#include <string>

#include "lib/svglite_utils.h"

#include "HttpgdDev.h"
#include "DrawData.h"

#include "fixsuspinter.h"

#include "RSync.h"

#define LOGDRAW 0

namespace httpgd
{

    // returns system path to {package}/inst/www/{filename}
    std::string get_wwwpath(const std::string &filename)
    {
        Rcpp::Environment base("package:base");
        Rcpp::Function sys_file = base["system.file"];
        Rcpp::StringVector res = sys_file("www", filename,
                                          Rcpp::_["package"] = "httpgd");
        return std::string(res[0]);
    }

    std::string read_txt(const std::string &filepath)
    {
        std::ifstream t(get_wwwpath("index.html"));
        std::stringstream buffer;
        buffer << t.rdbuf();
        return std::string(buffer.str());
    }

    inline HttpgdDev *getDev(pDevDesc dd)
    {
        return static_cast<HttpgdDev *>(dd->deviceSpecific);
    }

    // --------------------------------------

    /**
     * R Callback: Get singe char font metrics.
     */
    void httpgd_metric_info(int c, const pGEcontext gc, double *ascent,
                            double *descent, double *width, pDevDesc dd)
    {

        if (c < 0)
        {
            c = -c;
        }

        std::pair<std::string, int> font = get_font_file(gc->fontfamily, gc->fontface, getDev(dd)->user_aliases);

        int error = glyph_metrics(c, font.first.c_str(), font.second, gc->ps * gc->cex, 1e4, ascent, descent, width);
        if (error != 0)
        {
            *ascent = 0;
            *descent = 0;
            *width = 0;
        }
        double mod = 72. / 1e4;
        *ascent *= mod;
        *descent *= mod;
        *width *= mod;

#if LOGDRAW == 1
        Rprintf("METRIC_INFO c=%i ascent=%f descent=%f width=%f\n", c, ascent, descent, width);
#endif
    }

    /**
     * R Callback: Get String width.
     */
    double httpgd_strwidth(const char *str, const pGEcontext gc, pDevDesc dd)
    {

#if LOGDRAW == 1
        Rprintf("STRWIDTH str=\"%s\"\n", str);
#endif

        std::pair<std::string, int> font = get_font_file(gc->fontfamily, gc->fontface, getDev(dd)->user_aliases);

        double width = 0.0;

        int error = string_width(str, font.first.c_str(), font.second, gc->ps * gc->cex, 1e4, 1, &width);

        if (error != 0)
        {
            width = 0.0;
        }

        return width * 72. / 1e4;
    }

    /**
     * R Callback: Clip draw area.
     */
    void httpgd_clip(double x0, double x1, double y0, double y1, pDevDesc dd)
    {
        getDev(dd)->clip_page(x0, x1, y0, y1);
#if LOGDRAW == 1
        Rprintf("CLIP x0=%f x1=%f y0=%f y1=%f\n", x0, x1, y0, y1);
#endif
    }

    /**
     * R Callback: Start new page.
     */
    void httpgd_new_page(const pGEcontext gc, pDevDesc dd)
    {
        HttpgdDev *dev = getDev(dd);

        dev->new_page(dd->right, dd->bottom, dd->startfill);

#if LOGDRAW == 1
        Rcpp::Rcout << "NEW_PAGE \n";
#endif
    }

    /**
     * R Callback: Close graphics device.
     */
    void httpgd_close(pDevDesc dd)
    {
        Rcpp::Rcout << "Server closing... ";
        rsync::awaitLater();
        rsync::lock();
        rsync::unlock();

        HttpgdDev *dev = getDev(dd);
        dev->hist_clear();

        //dev->server.replaying = false; // todo remove (?)
        dev->shutdown_server();
        delete dev;

        Rcpp::Rcout << "Closed.\n";

#if LOGDRAW == 1
        Rcpp::Rcout << "CLOSE \n";
#endif
    }

    // -------------------------------------------
    // Draw Objects.
    // -------------------------------------------

    /**
     * R Callback: Draw line.
     */
    void httpgd_line(double x1, double y1, double x2, double y2,
                     const pGEcontext gc, pDevDesc dd)
    {
        getDev(dd)->put(std::make_shared<dc::Line>(gc, x1, y1, x2, y2));

#if LOGDRAW == 1
        Rprintf("LINE x1=%f y1=%f x2=%f y2=%f\n", x1, y1, x2, y2);
#endif
    }

    /**
     * R Callback: Draw polyline.
     */
    void httpgd_polyline(int n, double *x, double *y, const pGEcontext gc,
                         pDevDesc dd)
    {

        std::vector<double> vx(x, x + n);
        std::vector<double> vy(y, y + n);

        getDev(dd)->put(std::make_shared<dc::Polyline>(gc, n, vx, vy));

#if LOGDRAW == 1
        Rcpp::Rcout << "POLYLINE \n";
#endif
    }

    /**
     * R Callback: Draw polygon.
     */
    void httpgd_polygon(int n, double *x, double *y, const pGEcontext gc,
                        pDevDesc dd)
    {

        std::vector<double> vx(x, x + n);
        std::vector<double> vy(y, y + n);

        getDev(dd)->put(std::make_shared<dc::Polygon>(gc, n, vx, vy));

#if LOGDRAW == 1
        Rcpp::Rcout << "POLYGON \n";
#endif
    }

    /**
     * R Callback: Draw path.
     */
    void httpgd_path(double *x, double *y,
                     int npoly, int *nper,
                     Rboolean winding,
                     const pGEcontext gc, pDevDesc dd)
    {
        std::vector<int> vnper(nper, nper + npoly);
        int npoints = 0;
        for (int i = 0; i < npoly; i++)
        {
            npoints += vnper[i];
        }
        std::vector<double> vx(x, x + npoints);
        std::vector<double> vy(y, y + npoints);

        getDev(dd)->put(std::make_shared<dc::Path>(gc, vx, vy, npoly, vnper, winding));

#if LOGDRAW == 1
        Rcpp::Rcout << "PATH \n";
#endif
    }

    /**
     * R Callback: Draw rectangle.
     */
    void httpgd_rect(double x0, double y0, double x1, double y1,
                     const pGEcontext gc, pDevDesc dd)
    {
        getDev(dd)->put(std::make_shared<dc::Rect>(gc, x0, y0, x1, y1));

#if LOGDRAW == 1
        Rprintf("RECT x0=%f y0=%f x1=%f y1=%f\n", x0, y0, x1, y1);
#endif
    }

    /**
     * R Callback: Draw circle.
     */
    void httpgd_circle(double x, double y, double r, const pGEcontext gc,
                       pDevDesc dd)
    {
        getDev(dd)->put(std::make_shared<dc::Circle>(gc, x, y, r));

#if LOGDRAW == 1
        Rprintf("CIRCLE x=%f y=%f r=%f\n", x, y, r);
#endif
    }

    /**
     * R Callback: Draw text.
     */
    void httpgd_text(double x, double y, const char *str, double rot,
                     double hadj, const pGEcontext gc, pDevDesc dd)
    {

        HttpgdDev *dev = getDev(dd);

        dev->put(std::make_shared<dc::Text>(gc, x, y, str, rot, hadj,
                                            dc::TextInfo{
                                                fontname(gc->fontfamily, gc->fontface, dev->system_aliases, dev->user_aliases),
                                                gc->cex * gc->ps,
                                                is_bold(gc->fontface),
                                                is_italic(gc->fontface),
                                                httpgd_strwidth(str, gc, dd)}));

#if LOGDRAW == 1
        Rprintf("TEXT x=%f y=%f str=\"%s\" rot=%f hadj=%f\n", x, y, str, rot, hadj);
#endif
    }

    /**
     * R Callback: Get size of drawing.
     */
    void httpgd_size(double *left, double *right, double *bottom, double *top,
                     pDevDesc dd)
    {
        HttpgdDev *dev = getDev(dd);

        double w, h;
        dev->page_size(&w, &h);

        *left = 0.0;
        *right = w;
        *bottom = h;
        *top = 0.0;

#if LOGDRAW == 1
        Rprintf("SIZE left=%f right=%f bottom=%f top=%f\n", *left, *right, *bottom, *top);
#endif
    }

    /**
     * R Callback: Draw raster graphic.
     */
    void httpgd_raster(unsigned int *raster, int w, int h,
                       double x, double y,
                       double width, double height,
                       double rot,
                       Rboolean interpolate,
                       const pGEcontext gc, pDevDesc dd)
    {

        std::vector<unsigned int> raster_(raster, raster + (w * h));

        getDev(dd)->put(std::make_shared<dc::Raster>(gc, raster_, w, h, x, y, width, height, rot, interpolate));

#if LOGDRAW == 1
        Rcpp::Rcout << "RASTER \n";
#endif
    }

    /**
     * R Callback: start draw = 1, stop draw = 0
     */
    static void httpgd_mode(int mode, pDevDesc dd)
    {
        getDev(dd)->mode(mode);

#if LOGDRAW == 1
        Rprintf("MODE mode=%i\n", mode);
#endif
    }

    // R graphics device initialization procedure

    pDevDesc httpgd_driver_new(const HttpgdDevStartParams &t_params, const HttpgdServerConfig &t_config)
    {

        pDevDesc dd = (DevDesc *)calloc(1, sizeof(DevDesc));
        if (dd == nullptr)
        {
            return dd;
        }

        dd->startfill = t_params.bg;
        dd->startcol = R_RGB(0, 0, 0);
        dd->startps = t_params.pointsize;
        dd->startlty = 0;
        dd->startfont = 1;
        dd->startgamma = 1;

        // Callbacks
        dd->activate = nullptr;
        dd->deactivate = nullptr;
        dd->close = httpgd_close;
        dd->clip = httpgd_clip;
        dd->size = httpgd_size;
        dd->newPage = httpgd_new_page;
        dd->line = httpgd_line;
        dd->text = httpgd_text;
        dd->strWidth = httpgd_strwidth;
        dd->rect = httpgd_rect;
        dd->circle = httpgd_circle;
        dd->polygon = httpgd_polygon;
        dd->polyline = httpgd_polyline;
        dd->path = httpgd_path;
        dd->mode = httpgd_mode;
        dd->metricInfo = httpgd_metric_info;
        dd->cap = nullptr;
        dd->raster = httpgd_raster;

        // UTF-8 support
        dd->wantSymbolUTF8 = static_cast<Rboolean>(1);
        dd->hasTextUTF8 = static_cast<Rboolean>(1);
        dd->textUTF8 = httpgd_text;
        dd->strWidthUTF8 = httpgd_strwidth;

        // Screen Dimensions in pts
        dd->left = 0;
        dd->top = 0;
        dd->right = t_params.width;
        dd->bottom = t_params.height;

        // Magic constants copied from other graphics devices
        // nominal character sizes in pts
        dd->cra[0] = 0.9 * t_params.pointsize;
        dd->cra[1] = 1.2 * t_params.pointsize;
        // character alignment offsets
        dd->xCharOffset = 0.4900;
        dd->yCharOffset = 0.3333;
        dd->yLineBias = 0.2;
        // inches per pt
        dd->ipr[0] = 1.0 / 72.0;
        dd->ipr[1] = 1.0 / 72.0;

        // Capabilities
        dd->canClip = static_cast<Rboolean>(1);
        dd->canHAdj = 0;
        dd->canChangeGamma = static_cast<Rboolean>(0);
        dd->displayListOn = static_cast<Rboolean>(1); // toggles replayability
        dd->haveTransparency = 2;
        dd->haveTransparentBg = 2;

        dd->deviceSpecific = new HttpgdDev(dd, t_config, t_params);
        return dd;
    }

    void makehttpgdDevice(const HttpgdDevStartParams &t_params, const HttpgdServerConfig &t_config)
    {

        R_GE_checkVersionOrDie(R_GE_version);
        R_CheckDeviceAvailable();

        HTTPGD_BEGIN_SUSPEND_INTERRUPTS
        {
            if (check_server_started(t_config.host, t_config.port)) // todo: it should be possible to check if the port is occupied instead
            {
                Rcpp::stop("Failed to start httpgd. Server already running at this address!");
            }

            pDevDesc dev = httpgd_driver_new(t_params, t_config);
            if (dev == nullptr)
            {
                Rcpp::stop("Failed to start httpgd.");
            }

            pGEDevDesc dd = GEcreateDevDesc(dev);
            GEaddDevice2(dd, "httpgd");
            GEinitDisplayList(dd);

            getDev(dev)->start_server();
        }
        HTTPGD_END_SUSPEND_INTERRUPTS;
    }

} // namespace httpgd

// [[Rcpp::export]]
bool httpgd_(std::string host, int port, std::string bg, double width, double height,
             double pointsize, Rcpp::List aliases, bool recording, bool cors, std::string token)
{
    bool use_token = token.length();
    int ibg = R_GE_str2col(bg.c_str());

    std::string livehtml = httpgd::read_txt(httpgd::get_wwwpath("index.html"));

    httpgd::makehttpgdDevice({ibg,
                              width,
                              height,
                              pointsize,
                              aliases},
                             {host,
                              port,
                              livehtml,
                              cors,
                              use_token,
                              token,
                              recording});

    return true;
}

inline httpgd::HttpgdDev *validate_httpgddev(int devnum)
{
    if (devnum < 1 || devnum > 64) // R_MaxDevices
    {
        Rcpp::stop("invalid graphical device number");
    }

    pGEDevDesc gdd = GEgetDevice(devnum - 1);
    if (!gdd)
    {
        Rcpp::stop("invalid device");
    }
    pDevDesc dd = gdd->dev;
    if (!dd)
    {
        Rcpp::stop("invalid device");
    }
    auto dev = static_cast<httpgd::HttpgdDev *>(dd->deviceSpecific);
    if (!dev)
    {
        Rcpp::stop("invalid device");
    }

    return dev;
}

// [[Rcpp::export]]
Rcpp::List httpgd_state_(int devnum)
{
    auto dev = validate_httpgddev(devnum);

    auto svr_config = dev->get_server_config();

    return Rcpp::List::create(
        Rcpp::Named("host") = svr_config->host,
        Rcpp::Named("port") = dev->server_await_port(),
        Rcpp::Named("token") = svr_config->token,
        Rcpp::Named("hsize") = dev->store_get_page_count(),
        Rcpp::Named("upid") = dev->store_get_upid());
}

// [[Rcpp::export]]
std::string httpgd_random_token_(int len)
{
    if (len < 0)
    {
        Rcpp::stop("Length needs to be 0 or higher.");
    }
    return httpgd::HttpgdDev::random_token(len);
}

// [[Rcpp::export]]
std::string httpgd_svg_(int devnum, int page, double width, double height)
{
    auto dev = validate_httpgddev(devnum);
    return dev->store_svg(page, width, height);
}

// [[Rcpp::export]]
bool httpgd_remove_(int devnum, int page)
{
    auto dev = validate_httpgddev(devnum);
    return dev->store_remove(page);
}

// [[Rcpp::export]]
bool httpgd_clear_(int devnum)
{
    auto dev = validate_httpgddev(devnum);
    return dev->store_clear();
}