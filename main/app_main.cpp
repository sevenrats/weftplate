/*
 * weftplate — expose N dry-contact loops as Matter Contact Sensors over Thread
 * or Wi-Fi, on an ESP32-C6.
 *
 * Each loop is a GPIO with an internal pull-up: field contact shorts the pin to
 * GND. Contact CLOSED -> pin LOW -> Matter StateValue TRUE ("closed/contact",
 * per Matter Device Library spec, Contact Sensor). Contact OPEN -> pin HIGH ->
 * StateValue FALSE.
 *
 * The number of loops is set at build time via -DWEFTPLATE_NUM_LOOPS=N (1..6),
 * supplied by build.sh. Default 6.
 *
 * The transport is set at build time via -DWEFTPLATE_TRANSPORT=thread|wifi
 * (top-level CMakeLists.txt), which picks transport/<transport>.defaults. The
 * code below follows from the resulting CHIP_DEVICE_CONFIG_ENABLE_* macros.
 *
 * Dry contacts ONLY. These GPIOs carry the C6's own 3.3V logic to GND through
 * your loop. Never connect them to mains or any external voltage.
 */

#include <esp_log.h>
#include <esp_matter.h>
#include <esp_matter_ota.h>
#include <nvs_flash.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <driver/gpio.h>

#if CHIP_DEVICE_CONFIG_ENABLE_THREAD
// Declares set_openthread_platform_config() and the OpenThread types.
#include <platform/ESP32/OpenthreadLauncher.h>

// The ESP_OPENTHREAD_DEFAULT_*_CONFIG macros are not exported by any library
// header; every esp-matter/esp-idf example defines them locally. Copied verbatim
// from esp-matter examples/*/main/app_priv.h (native radio, no RCP host link).
#define ESP_OPENTHREAD_DEFAULT_RADIO_CONFIG()                                            \
    {                                                                                   \
        .radio_mode = RADIO_MODE_NATIVE,                                                \
    }

#define ESP_OPENTHREAD_DEFAULT_HOST_CONFIG()                                             \
    {                                                                                   \
        .host_connection_mode = HOST_CONNECTION_MODE_NONE,                              \
    }

#define ESP_OPENTHREAD_DEFAULT_PORT_CONFIG()                                             \
    {                                                                                   \
        .storage_partition_name = "nvs", .netif_queue_size = 10, .task_queue_size = 10, \
    }
#endif

using namespace esp_matter;
using namespace esp_matter::endpoint;
using namespace chip::app::Clusters;

static const char *TAG = "weftplate";

// Abort with a log if a required setup step fails (self-contained; avoids
// depending on esp-matter's examples/common when built as a managed component).
#define ABORT_APP_ON_FAILURE(cond, log) \
    do { \
        if (!(unlikely(cond))) { \
            log; \
            vTaskDelay(pdMS_TO_TICKS(5000)); \
            abort(); \
        } \
    } while (0)

#ifndef WEFTPLATE_NUM_LOOPS
#define WEFTPLATE_NUM_LOOPS 6
#endif
#if WEFTPLATE_NUM_LOOPS < 1 || WEFTPLATE_NUM_LOOPS > 6
#error "WEFTPLATE_NUM_LOOPS must be between 1 and 6"
#endif

static constexpr int NUM_LOOPS = WEFTPLATE_NUM_LOOPS;

/*
 * Loop input pins for the Seeed XIAO ESP32-C6.
 * These are the board's D0..D5 pads (a contiguous run on one side), chosen to
 * avoid the UART0 console (D6/D7 = GPIO16/17), strapping, flash and USB pins.
 *
 *   Loop 1 = D0 = GPIO0
 *   Loop 2 = D1 = GPIO1
 *   Loop 3 = D2 = GPIO2
 *   Loop 4 = D3 = GPIO21
 *   Loop 5 = D4 = GPIO22
 *   Loop 6 = D5 = GPIO23
 */
static const gpio_num_t LOOP_GPIOS[6] = {
    GPIO_NUM_0, GPIO_NUM_1, GPIO_NUM_2, GPIO_NUM_21, GPIO_NUM_22, GPIO_NUM_23,
};

// Software debounce window.
static constexpr uint32_t DEBOUNCE_MS = 40;
static constexpr uint32_t POLL_MS = 10;

static uint16_t s_ep_ids[NUM_LOOPS];
static bool s_last_closed[NUM_LOOPS];

// Contact CLOSED == pin driven LOW (shorted to GND through the field loop).
static inline bool read_closed(int i)
{
    return gpio_get_level(LOOP_GPIOS[i]) == 0;
}

// Push a loop's state to its Matter endpoint. Must run on the Matter task.
static void publish_state(uint16_t endpoint_id, bool closed)
{
    esp_matter_attr_val_t val = esp_matter_bool(closed);  // true = closed/contact
    attribute::update(endpoint_id,
                      BooleanState::Id,                        // 0x0045
                      BooleanState::Attributes::StateValue::Id, // 0x0000
                      &val);
}

// Poll + debounce all loops; schedule attribute updates on the Matter stack.
static void loop_task(void *arg)
{
    uint32_t stable_ms[NUM_LOOPS] = {0};
    bool candidate[NUM_LOOPS];
    for (int i = 0; i < NUM_LOOPS; i++) {
        s_last_closed[i] = read_closed(i);
        candidate[i] = s_last_closed[i];
    }

    while (true) {
        for (int i = 0; i < NUM_LOOPS; i++) {
            bool now = read_closed(i);
            if (now != candidate[i]) {
                candidate[i] = now;      // level changed; restart debounce
                stable_ms[i] = 0;
            } else if (candidate[i] != s_last_closed[i]) {
                stable_ms[i] += POLL_MS;
                if (stable_ms[i] >= DEBOUNCE_MS) {
                    s_last_closed[i] = candidate[i];
                    uint16_t ep = s_ep_ids[i];
                    bool closed = candidate[i];
                    ESP_LOGI(TAG, "loop %d (ep %u) -> %s", i, ep,
                             closed ? "CLOSED" : "OPEN");
                    // attribute::update must run on the Matter/CHIP task.
                    chip::DeviceLayer::SystemLayer().ScheduleLambda(
                        [ep, closed]() { publish_state(ep, closed); });
                }
            }
        }
        vTaskDelay(pdMS_TO_TICKS(POLL_MS));
    }
}

static esp_err_t app_attribute_update_cb(attribute::callback_type_t type,
                                         uint16_t endpoint_id, uint32_t cluster_id,
                                         uint32_t attribute_id,
                                         esp_matter_attr_val_t *val, void *priv_data)
{
    return ESP_OK;  // contact sensors are read-only; nothing to accept from controllers
}

static esp_err_t app_identification_cb(identification::callback_type_t type,
                                       uint16_t endpoint_id, uint8_t effect_id,
                                       uint8_t effect_variant, void *priv_data)
{
    ESP_LOGI(TAG, "identify: type %u, ep %u", type, endpoint_id);
    return ESP_OK;
}

static void app_event_cb(const ChipDeviceEvent *event, intptr_t arg)
{
    // Optional: log commissioning/Thread events. Left minimal on purpose.
}

extern "C" void app_main()
{
    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ESP_ERROR_CHECK(nvs_flash_init());
    }

    // Configure the loop GPIOs as inputs with internal pull-ups.
    for (int i = 0; i < NUM_LOOPS; i++) {
        gpio_config_t io = {};
        io.pin_bit_mask = 1ULL << LOOP_GPIOS[i];
        io.mode = GPIO_MODE_INPUT;
        io.pull_up_en = GPIO_PULLUP_ENABLE;
        io.pull_down_en = GPIO_PULLDOWN_DISABLE;
        io.intr_type = GPIO_INTR_DISABLE;  // we poll + debounce, no ISR
        ESP_ERROR_CHECK(gpio_config(&io));
    }

    // Root node on endpoint 0.
    node::config_t node_config;
    node_t *node = node::create(&node_config, app_attribute_update_cb,
                                app_identification_cb);
    ABORT_APP_ON_FAILURE(node != nullptr, ESP_LOGE(TAG, "failed to create node"));

    // One Contact Sensor endpoint per loop, seeded with the current level.
    for (int i = 0; i < NUM_LOOPS; i++) {
        contact_sensor::config_t cfg;
        cfg.boolean_state.state_value = read_closed(i);  // true = closed/contact
        endpoint_t *ep = contact_sensor::create(node, &cfg, ENDPOINT_FLAG_NONE, nullptr);
        ABORT_APP_ON_FAILURE(ep != nullptr, ESP_LOGE(TAG, "failed to create ep %d", i));
        s_ep_ids[i] = endpoint::get_id(ep);
        ESP_LOGI(TAG, "loop %d -> GPIO%d -> endpoint %u", i, LOOP_GPIOS[i], s_ep_ids[i]);
    }

#if CHIP_DEVICE_CONFIG_ENABLE_THREAD
    esp_openthread_platform_config_t ot_config = {
        .radio_config = ESP_OPENTHREAD_DEFAULT_RADIO_CONFIG(),
        .host_config = ESP_OPENTHREAD_DEFAULT_HOST_CONFIG(),
        .port_config = ESP_OPENTHREAD_DEFAULT_PORT_CONFIG(),
    };
    set_openthread_platform_config(&ot_config);
#endif

    ESP_ERROR_CHECK(esp_matter::start(app_event_cb));

    xTaskCreate(loop_task, "contact_loops", 4096, nullptr, 5, nullptr);

#if CHIP_DEVICE_CONFIG_ENABLE_THREAD
    static const char *transport = "Thread";
#else
    static const char *transport = "Wi-Fi";
#endif
    ESP_LOGI(TAG, "weftplate up: %d loop(s) as Matter contact sensors over %s",
             NUM_LOOPS, transport);
}
