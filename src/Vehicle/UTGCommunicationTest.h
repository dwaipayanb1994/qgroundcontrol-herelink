/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

/// @file
/// @brief UTGCommunication unit tests

#pragma once

#include "UnitTest.h"
#include "UTGCommunication.h"
#include "Vehicle.h"
#include "MultiVehicleManager.h"
#include "QGCApplication.h"

/// Unit tests for UTGCommunication class
class UTGCommunicationTest : public UnitTest
{
    Q_OBJECT
    
public:
    UTGCommunicationTest();

private slots:
    void init();
    void cleanup();
    
    // Basic functionality tests
    void _testConstruction();
    void _testConnectionManagement();
    void _testCommandSending();
    void _testResponseParsing();
    void _testSettingsIntegration();
    
    // MAVLink message tests
    void _testSerialControlMessageHandling();
    void _testMessageGeneration();
    
    // Command queue tests
    void _testCommandQueue();
    void _testCommandTimeout();
    
    // Property tests
    void _testPropertyUpdates();
    void _testSignalEmission();
    
    // Error handling tests
    void _testErrorHandling();
    void _testInvalidResponses();
    
    // Integration tests
    void _testVehicleIntegration();
    void _testSettingsSync();
    void _testVelocityV1Ack();
    void _testSettingsPushWhenConnected();
    void _testVelocitySyncFromDevice();
    void _testStableMeasurementAutoSave();
    void _testStableMeasurementWithZoneNotes();
    void _testContinuousMeasurementProperty();

private:
    // Helper methods
    void _createTestVehicle();
    void _destroyTestVehicle();
    mavlink_message_t _createSerialControlMessage(const QString& data);
    void _simulateUTGResponse(const QString& response);
    
    // Test data
    Vehicle* _testVehicle;
    UTGCommunication* _utgComm;
    QSignalSpy* _connectedSpy;
    QSignalSpy* _thicknessSpy;
    QSignalSpy* _errorSpy;
};
