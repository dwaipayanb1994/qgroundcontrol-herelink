/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "UTGCommunicationTest.h"
#include "QGCApplication.h"
#include "SettingsManager.h"
#include "UTGSettings.h"
#include "UTGReadingManager.h"

#include <QSignalSpy>
#include <QTest>

UTGCommunicationTest::UTGCommunicationTest()
    : _testVehicle(nullptr)
    , _utgComm(nullptr)
    , _connectedSpy(nullptr)
    , _thicknessSpy(nullptr)
    , _errorSpy(nullptr)
{
}

void UTGCommunicationTest::init()
{
    UnitTest::init();
    _createTestVehicle();
}

void UTGCommunicationTest::cleanup()
{
    _destroyTestVehicle();
    UnitTest::cleanup();
}

void UTGCommunicationTest::_createTestVehicle()
{
    if (_testVehicle) {
        _destroyTestVehicle();
    }
    
    // Create a test vehicle
    _testVehicle = new Vehicle(1, MAV_AUTOPILOT_ARDUPILOTMEGA, MAV_TYPE_QUADROTOR, 
                               qgcApp()->toolbox()->firmwarePluginManager(), this);
    
    // Create UTGCommunication instance
    _utgComm = new UTGCommunication(_testVehicle, this);
    
    // Setup signal spies
    _connectedSpy = new QSignalSpy(_utgComm, &UTGCommunication::connectionStatusChanged);
    _thicknessSpy = new QSignalSpy(_utgComm, &UTGCommunication::measurementReceived);
    _errorSpy = new QSignalSpy(_utgComm, &UTGCommunication::errorOccurred);
}

void UTGCommunicationTest::_destroyTestVehicle()
{
    delete _connectedSpy;
    delete _thicknessSpy;
    delete _errorSpy;
    delete _utgComm;
    delete _testVehicle;
    
    _connectedSpy = nullptr;
    _thicknessSpy = nullptr;
    _errorSpy = nullptr;
    _utgComm = nullptr;
    _testVehicle = nullptr;
}

void UTGCommunicationTest::_testConstruction()
{
    QVERIFY(_utgComm != nullptr);
    QVERIFY(!_utgComm->connected());
    QCOMPARE(_utgComm->currentThickness(), 0.0);
    QVERIFY(_utgComm->deviceVersion().isEmpty());
    QVERIFY(_utgComm->lastError().isEmpty());
}

void UTGCommunicationTest::_testConnectionManagement()
{
    // Test initial state
    QVERIFY(!_utgComm->connected());
    
    // Test connect command
    _utgComm->connectToUTG();
    
    // Simulate successful connection response (UTG specification format)
    _simulateUTGResponse("I3 A 1.35I IDUT0001");

    // Should be connected now
    QVERIFY(_utgComm->connected());
    QCOMPARE(_connectedSpy->count(), 1);
    QCOMPARE(_utgComm->deviceVersion(), QString("1.35I IDUT0001"));
    
    // Test disconnect
    _utgComm->disconnectFromUTG();
    QVERIFY(!_utgComm->connected());
    QCOMPARE(_connectedSpy->count(), 2);
}

void UTGCommunicationTest::_testCommandSending()
{
    // Connect first
    _utgComm->connectToUTG();
    _simulateUTGResponse("I3 A 1.35I IDUT0001");

    // Test thickness measurement
    _utgComm->measureThickness();

    // Simulate thickness response (UTG specification format)
    _simulateUTGResponse("S A 12.345 mm");

    QCOMPARE(_utgComm->currentThickness(), 12.345);
    QCOMPARE(_thicknessSpy->count(), 1);
}

void UTGCommunicationTest::_testResponseParsing()
{
    // Test various response formats (UTG specification format)
    _simulateUTGResponse("I3 A 1.35I IDUT0001");
    QCOMPARE(_utgComm->deviceVersion(), QString("1.35I IDUT0001"));

    _simulateUTGResponse("S A 25.678 mm");
    QCOMPARE(_utgComm->currentThickness(), 25.678);

    _simulateUTGResponse("TEMP A 23.5");  // Custom command, not in UTG spec
    QCOMPARE(_utgComm->temperature(), 23.5);

    _simulateUTGResponse("V0 A 5920 m/s");
    QCOMPARE(_utgComm->velocity(), 5920.0);

    _simulateUTGResponse("I3 E");  // Error response
    QVERIFY(!_utgComm->lastError().isEmpty());
    QCOMPARE(_errorSpy->count(), 1);
}

void UTGCommunicationTest::_testSettingsIntegration()
{
    // Get settings
    UTGSettings* settings = qgcApp()->toolbox()->settingsManager()->utgSettings();
    QVERIFY(settings != nullptr);
    
    // Test that UTGCommunication uses settings values
    double originalVelocity = settings->soundVelocity()->rawValue().toDouble();
    int originalGain = settings->gain()->rawValue().toInt();
    
    // Change settings
    settings->soundVelocity()->setRawValue(6000.0);
    settings->gain()->setRawValue(75);
    
    // Create new UTGCommunication instance
    UTGCommunication* newComm = new UTGCommunication(_testVehicle, this);
    
    // Should use new settings values
    QCOMPARE(newComm->velocity(), 6000.0);
    QCOMPARE(newComm->gain(), 75);
    
    // Restore original values
    settings->soundVelocity()->setRawValue(originalVelocity);
    settings->gain()->setRawValue(originalGain);
    
    delete newComm;
}

void UTGCommunicationTest::_testSerialControlMessageHandling()
{
    // Create a test SERIAL_CONTROL message (this tests the old format for compatibility)
    mavlink_message_t msg = _createSerialControlMessage("S A 15.234 mm\r\n");

    // Handle the message
    _utgComm->handleSerialControlMessage(msg);

    // Should update thickness
    QCOMPARE(_utgComm->currentThickness(), 15.234);
}

void UTGCommunicationTest::_testCommandQueue()
{
    // Connect first
    _utgComm->connectToUTG();
    _simulateUTGResponse("I3 A 1.35I IDUT0001");

    // Send multiple commands quickly
    _utgComm->measureThickness();
    _utgComm->getTemperature();
    _utgComm->setVelocityCommand(6000.0);

    // Commands should be queued and processed in order
    // This is tested by checking that responses are handled correctly
    _simulateUTGResponse("S A 10.0 mm");
    _simulateUTGResponse("TEMP A 25.0");  // Custom command
    _simulateUTGResponse("V1 A");  // Set velocity acknowledgment

    QCOMPARE(_utgComm->currentThickness(), 10.0);
    QCOMPARE(_utgComm->temperature(), 25.0);
    QCOMPARE(_utgComm->velocity(), 6000.0);
}

void UTGCommunicationTest::_testErrorHandling()
{
    // Test invalid response
    _simulateUTGResponse("INVALID response format");

    // Should set error
    QVERIFY(!_utgComm->lastError().isEmpty());
    QCOMPARE(_errorSpy->count(), 1);
    
    // Test timeout simulation
    _utgComm->connectToUTG();
    // Don't send response - should timeout
    QTest::qWait(6000); // Wait longer than timeout
    
    // Should have error
    QVERIFY(!_utgComm->lastError().isEmpty());
}

mavlink_message_t UTGCommunicationTest::_createSerialControlMessage(const QString& data)
{
    mavlink_message_t msg;
    QByteArray dataBytes = data.toUtf8();
    
    mavlink_msg_serial_control_pack(
        1, 1, &msg,
        SERIAL_CONTROL_DEV_UTG,
        SERIAL_CONTROL_FLAG_RESPOND,
        0, 0,
        dataBytes.length(),
        reinterpret_cast<const uint8_t*>(dataBytes.constData())
    );
    
    return msg;
}

void UTGCommunicationTest::_simulateUTGResponse(const QString& response)
{
    // UTG responses come via STATUSTEXT messages with "UTG_RESPONSE: " prefix
    mavlink_message_t msg;
    mavlink_statustext_t statusText;

    QString fullResponse = QString("UTG_RESPONSE: %1").arg(response);
    QByteArray responseBytes = fullResponse.toUtf8();

    // Clear the text buffer
    memset(statusText.text, 0, sizeof(statusText.text));

    // Copy response text (max 50 characters for STATUSTEXT)
    int copyLen = qMin(responseBytes.length(), (int)sizeof(statusText.text) - 1);
    memcpy(statusText.text, responseBytes.constData(), copyLen);

    statusText.severity = MAV_SEVERITY_INFO;

    mavlink_msg_statustext_encode(1, 1, &msg, &statusText);
    _utgComm->handleStatusTextMessage(msg);
}

void UTGCommunicationTest::_testMessageGeneration()
{
    // This would test the actual MAVLink message generation
    // For now, we'll just verify the command is sent
    _utgComm->connectToUTG();
    
    // The actual message sending would be tested with a mock MAVLink protocol
    // For this unit test, we focus on the response handling
}

void UTGCommunicationTest::_testCommandTimeout()
{
    _utgComm->connectToUTG();
    // Don't send response - should timeout after 5 seconds
    QTest::qWait(6000);
    
    // Should have timeout error
    QVERIFY(_utgComm->lastError().contains("timeout") || 
            _utgComm->lastError().contains("Timeout"));
}

void UTGCommunicationTest::_testPropertyUpdates()
{
    // Test that property changes emit signals
    _simulateUTGResponse("S A 99.999 mm");
    QCOMPARE(_thicknessSpy->count(), 1);

    _simulateUTGResponse("S E");  // Error response
    QCOMPARE(_errorSpy->count(), 1);
}

void UTGCommunicationTest::_testSignalEmission()
{
    // Test all signal emissions
    QSignalSpy tempSpy(_utgComm, &UTGCommunication::temperatureChanged);
    QSignalSpy velSpy(_utgComm, &UTGCommunication::velocityChanged);
    QSignalSpy gainSpy(_utgComm, &UTGCommunication::gainChanged);
    
    _simulateUTGResponse("TEMP A 30.5");  // Custom command
    QCOMPARE(tempSpy.count(), 1);

    _simulateUTGResponse("V0 A 6200 m/s");
    QCOMPARE(velSpy.count(), 1);
    
    // Gain changes through settings
    UTGSettings* settings = qgcApp()->toolbox()->settingsManager()->utgSettings();
    if (settings) {
        settings->gain()->setRawValue(80);
        QCOMPARE(gainSpy.count(), 1);
    }
}

void UTGCommunicationTest::_testInvalidResponses()
{
    // Test various invalid response formats
    _simulateUTGResponse("MALFORMED");
    QVERIFY(!_utgComm->lastError().isEmpty());

    _simulateUTGResponse("S A not_a_number mm");
    QVERIFY(!_utgComm->lastError().isEmpty());

    _simulateUTGResponse("");
    QVERIFY(!_utgComm->lastError().isEmpty());
}

void UTGCommunicationTest::_testVehicleIntegration()
{
    QVERIFY(_utgComm != nullptr);
    QVERIFY(_testVehicle != nullptr);
}

void UTGCommunicationTest::_testSettingsSync()
{
    // Test that settings changes are reflected in UTGCommunication
    UTGSettings* settings = qgcApp()->toolbox()->settingsManager()->utgSettings();
    if (settings) {
        double newVelocity = 7000.0;
        settings->soundVelocity()->setRawValue(newVelocity);
        
        // Should update UTGCommunication velocity
        QCOMPARE(_utgComm->velocity(), newVelocity);
    }
}

void UTGCommunicationTest::_testVelocityV1Ack()
{
    QSignalSpy appliedSpy(_utgComm, &UTGCommunication::velocityApplied);

    _utgComm->setVelocityCommand(6420.0);
    _simulateUTGResponse("V1 A");

    QCOMPARE(_utgComm->velocity(), 6420.0);
    QCOMPARE(appliedSpy.count(), 1);
    QCOMPARE(appliedSpy.at(0).at(0).toDouble(), 6420.0);
}

void UTGCommunicationTest::_testSettingsPushWhenConnected()
{
    UTGSettings* settings = qgcApp()->toolbox()->settingsManager()->utgSettings();
    QVERIFY(settings != nullptr);

    const double originalVelocity = settings->soundVelocity()->rawValue().toDouble();

    _utgComm->connectToUTG();
    _simulateUTGResponse("I2 A UTG-2600 mm");
    _simulateUTGResponse("V0 A 5920 m/s");
    _simulateUTGResponse("P0 A P5EE");

    QVERIFY(_utgComm->connected());

    settings->soundVelocity()->setRawValue(6500.0);
    QCOMPARE(_utgComm->velocity(), 6500.0);

    _simulateUTGResponse("V1 A");
    QCOMPARE(_utgComm->velocity(), 6500.0);

    settings->soundVelocity()->setRawValue(originalVelocity);
}

void UTGCommunicationTest::_testVelocitySyncFromDevice()
{
    UTGSettings* settings = qgcApp()->toolbox()->settingsManager()->utgSettings();
    QVERIFY(settings != nullptr);

    const double originalVelocity = settings->soundVelocity()->rawValue().toDouble();

    _simulateUTGResponse("V0 A 6100 m/s");
    QCOMPARE(_utgComm->velocity(), 6100.0);
    QCOMPARE(settings->soundVelocity()->rawValue().toDouble(), 6100.0);

    // Device read-back should not trigger another device push while already in sync
    _simulateUTGResponse("V0 A 6100 m/s");
    QCOMPARE(_utgComm->velocity(), 6100.0);

    settings->soundVelocity()->setRawValue(originalVelocity);
}

void UTGCommunicationTest::_testStableMeasurementAutoSave()
{
    UTGSettings* settings = qgcApp()->toolbox()->settingsManager()->utgSettings();
    QVERIFY(settings != nullptr);

    const bool originalAutoSave = settings->autoSaveMeasurements()->rawValue().toBool();
    settings->autoSaveMeasurements()->setRawValue(true);

    UTGReadingManager* readingManager = _utgComm->readingManager();
    QVERIFY(readingManager != nullptr);
    readingManager->clearAll();

    _simulateUTGResponse("SI A 10.1 mm");
    _simulateUTGResponse("SI A 10.2 mm");
    _simulateUTGResponse("SI A 10.3 mm");
    QCOMPARE(_utgComm->currentThickness(), 10.3);
    QCOMPARE(_thicknessSpy->count(), 3);
    QCOMPARE(readingManager->rowCount(), 3);

    _simulateUTGResponse("S A 12.345 mm");
    QCOMPARE(_utgComm->currentThickness(), 12.345);
    QCOMPARE(_thicknessSpy->count(), 4);
    QCOMPARE(readingManager->rowCount(), 4);

    readingManager->clearAll();
    settings->autoSaveMeasurements()->setRawValue(originalAutoSave);
}

void UTGCommunicationTest::_testStableMeasurementWithZoneNotes()
{
    UTGSettings* settings = qgcApp()->toolbox()->settingsManager()->utgSettings();
    QVERIFY(settings != nullptr);

    const bool originalAutoSave = settings->autoSaveMeasurements()->rawValue().toBool();
    settings->autoSaveMeasurements()->setRawValue(true);

    UTGReadingManager* readingManager = _utgComm->readingManager();
    QVERIFY(readingManager != nullptr);
    readingManager->clearAll();

    _utgComm->setNextReadingNotes(QStringLiteral("Zone A 1"));
    _simulateUTGResponse("S A 12.345 mm");
    QCOMPARE(readingManager->rowCount(), 1);
    QCOMPARE(readingManager->notesAt(0), QStringLiteral("Zone A 1"));

    readingManager->clearAll();
    settings->autoSaveMeasurements()->setRawValue(originalAutoSave);
}

void UTGCommunicationTest::_testContinuousMeasurementProperty()
{
    QVERIFY(!_utgComm->continuousMeasurement());

    _utgComm->connectToUTG();
    _simulateUTGResponse("I2 A UTG-2600 mm");
    QVERIFY(_utgComm->connected());

    QSignalSpy continuousSpy(_utgComm, &UTGCommunication::continuousMeasurementChanged);

    _utgComm->startContinuousMeasurement();
    QVERIFY(_utgComm->continuousMeasurement());
    QCOMPARE(continuousSpy.count(), 1);
    QCOMPARE(continuousSpy.at(0).at(0).toBool(), true);

    _utgComm->stopContinuousMeasurement();
    QVERIFY(!_utgComm->continuousMeasurement());
    QCOMPARE(continuousSpy.count(), 2);
    QCOMPARE(continuousSpy.at(1).at(0).toBool(), false);

    _utgComm->disconnectFromUTG();
    QVERIFY(!_utgComm->continuousMeasurement());
}
