#!/usr/bin/env python3
"""
Smart Factory Sensor Simulator

Generates realistic IoT sensor data by simulating equipment degradation over time.
This demonstrates how equipment health declines, leading to predictive maintenance opportunities.

Why this matters:
- Real equipment doesn't fail instantly—it shows warning signs (increasing temperature, vibration)
- Our simulator models this realistic behavior so we can predict failures
- We're essentially creating the "ground truth" data that an analytics pipeline would process

Data flow:
1. Load config.yml (equipment types, sensor ranges, degradation parameters)
2. Initialize 5 equipment units with 100% health
3. For each hour over 7 days:
   - Calculate health decay for each equipment (random rate)
   - Generate "normal" sensor readings + noise
   - Add anomalies if equipment is degrading/failing
   - Write all readings to CSV
4. Output: 50,400 rows (5 equipment × 7 days × 24 hours × 60 readings/hour)

Key concepts:
- Degradation model: Health decreases linearly + random variance
- Sensor correlation: When vibration spikes, temperature often rises too (realistic!)
- Anomalies: Cluster together as equipment approaches failure
"""

import yaml
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from pathlib import Path
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


class SensorSimulator:
    """
    Simulates IoT sensors on factory equipment with realistic degradation patterns.
    """
    
    def __init__(self, config_path: str = "config.yml", seed: int = None):
        """
        Initialize simulator with configuration.
        
        Args:
            config_path: Path to YAML config file
            seed: Random seed for reproducibility (None = random each run)
        """
        # Load configuration
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        # Set random seed for reproducibility
        if seed is not None:
            np.random.seed(seed)
        else:
            seed = self.config['simulation'].get('random_seed', 42)
            np.random.seed(seed)
        
        logger.info(f"Initialized SensorSimulator with seed={seed}")
        
        # Parse simulation parameters
        self.duration_days = self.config['simulation']['duration_days']
        self.interval_minutes = self.config['simulation']['interval_minutes']
        self.batch_hours = self.config['simulation'].get('batch_hours', 24)
        self.start_health = self.config['degradation']['health_score_start']
        
        # Calculate total readings
        self.readings_per_day = (24 * 60) // self.interval_minutes
        self.total_days = self.duration_days
        self.readings_per_equipment = self.readings_per_day * self.total_days
        
        logger.info(
            f"Simulating {self.total_days} days, "
            f"{self.interval_minutes}-minute intervals, "
            f"{self.readings_per_equipment} readings per equipment"
        )
        logger.info(f"Batch size: {self.batch_hours} hour(s)")
        
        # Initialize equipment with random health decline rates
        self._initialize_equipment()
    
    def _initialize_equipment(self):
        """
        Create equipment inventory with random degradation rates.
        
        Each equipment has a daily health loss rate, randomly assigned from min/max.
        This makes some equipment fail faster than others (realistic!).
        """
        self.equipment_list = []
        config_sim = self.config['simulation']['num_equipments']
        
        # Generate equipment degradation rates
        health_loss_min = self.config['degradation']['daily_health_loss_min']
        health_loss_max = self.config['degradation']['daily_health_loss_max']
        degradation_variance = self.config['degradation']['degradation_variance']
        
        equipment_id = 0
        for equipment_type, count in config_sim.items():
            for i in range(count):
                # Random degradation rate for this equipment
                base_rate = np.random.uniform(health_loss_min, health_loss_max)
                variance = np.random.normal(0, degradation_variance)
                daily_loss = max(0.1, base_rate + variance)  # Ensure positive
                
                equipment = {
                    'id': f"{equipment_type}_{i+1:03d}",
                    'type': equipment_type,
                    'daily_health_loss_rate': daily_loss,
                    'initial_health': self.start_health,
                }
                
                self.equipment_list.append(equipment)
                equipment_id += 1
                
                logger.info(
                    f"Equipment {equipment['id']}: "
                    f"daily health loss = {daily_loss:.3f}% → "
                    f"estimated failure in {100 / daily_loss:.0f} days"
                )
    
    def _calculate_health_at_timestamp(self, equipment: dict, timestamp: datetime) -> float:
        """
        Calculate equipment health score at given timestamp.
        
        Formula: Health = 100% - (daily_loss_rate * days_elapsed)
        With small random variance to simulate unpredictability.
        
        Args:
            equipment: Equipment dict with degradation rate
            timestamp: Current simulation timestamp
        
        Returns:
            Health score (0-100)
        """
        # Calculate days elapsed since simulation start
        simulation_start = datetime(year=2026, month=3, day=24)
        days_elapsed = (timestamp - simulation_start).total_seconds() / (24 * 3600)
        
        # Linear degradation + small random walk
        base_health = 100.0 - (equipment['daily_health_loss_rate'] * days_elapsed)
        
        # Add random variance (small ±wiggle)
        variance = np.random.normal(0, 0.5)
        health = base_health + variance
        
        # Clamp to valid range
        return max(0, min(100, health))
    
    def _generate_sensor_reading(
        self, 
        equipment: dict, 
        timestamp: datetime, 
        health_score: float
    ) -> dict:
        """
        Generate realistic sensor readings based on equipment health.
        
        Logic:
        - Healthy (>70%): Small random noise, no anomalies
        - Degrading (50-70%): Increasing spikes/variance
        - Critical (<30%): Constant anomalies, correlated across sensors
        
        This models real equipment behavior: as it fails, sensor readings become erratic.
        
        Args:
            equipment: Equipment dict
            timestamp: Current timestamp
            health_score: Current health percentage (0-100)
        
        Returns:
            Dict with sensor readings
        """
        equipment_type = equipment['type']
        equipment_id = equipment['id']
        
        # Get sensor configuration for this equipment type
        sensor_config = self.config['equipment_types'][equipment_type]['sensors']
        
        reading = {
            'timestamp': timestamp,
            'equipment_id': equipment_id,
            'equipment_type': equipment_type,
            'health_score': health_score,
        }
        
        # Generate each sensor
        is_anomaly = False
        anomaly_reasons = []
        
        for sensor_name, sensor_spec in sensor_config.items():
            # Base reading from normal distribution
            base_value = np.random.normal(
                sensor_spec['normal_mean'],
                sensor_spec['normal_std']
            )
            
            # Adjust spread based on health (worse health = more variance)
            if health_score > 70:
                # Healthy: tight variance, no anomalies
                multiplier = 1.0
                spike_threshold = 3.0  # Strict: need 3σ deviation
            elif health_score > 50:
                # Degrading: increasing variance
                multiplier = 1.5
                spike_threshold = 2.0  # Moderate: 2σ deviation
            else:
                # Critical: high variance, frequent anomalies
                multiplier = 2.5
                spike_threshold = 1.5  # Sensitive: 1.5σ deviation
            
            # Add degradation-based noise
            degradation_noise = np.random.normal(0, sensor_spec['normal_std'] * (multiplier - 1))
            value = base_value + degradation_noise
            
            # Clamp to sensor range
            value = np.clip(value, sensor_spec['min'], sensor_spec['max'])
            
            # Detect anomalies (spikes, out of normal range)
            deviation_std = abs(value - sensor_spec['normal_mean']) / sensor_spec['normal_std']
            is_sensor_anomaly = deviation_std > spike_threshold
            
            if is_sensor_anomaly:
                is_anomaly = True
                anomaly_reasons.append(f"{sensor_name}_spike")
            
            reading[sensor_name] = round(value, 2)
        
        # Add anomaly flags
        reading['is_anomaly'] = 1 if is_anomaly else 0
        reading['anomaly_reason'] = ', '.join(anomaly_reasons) if anomaly_reasons else None
        
        return reading

    def _generate_batch(
        self,
        equipment: dict,
        batch_start: datetime,
        batch_end: datetime,
    ) -> list[dict]:
        """
        Generate readings for one equipment within a bounded time window.

        This keeps the simulation time-series based while allowing the pipeline
        to emit data in smaller batches instead of holding the entire dataset
        in memory at once.
        """
        batch_readings = []
        current_time = batch_start

        while current_time < batch_end:
            health_score = self._calculate_health_at_timestamp(equipment, current_time)
            reading = self._generate_sensor_reading(equipment, current_time, health_score)
            batch_readings.append(reading)
            current_time += timedelta(minutes=self.interval_minutes)

        return batch_readings
    
    def generate_data(self) -> pd.DataFrame:
        """
        Generate all simulated sensor data.
        
        Generates readings for all equipment over the full simulation period
        in time-based batches, writing progress to console every 10,000 rows.
        
        Returns:
            DataFrame with columns: timestamp, equipment_id, equipment_type,
                                   temperature, vibration, power_consumption,
                                   health_score, is_anomaly, anomaly_reason
        """
        logger.info(f"Generating sensor data...")
        logger.info(f"Total rows to generate: {len(self.equipment_list) * self.readings_per_equipment:,}")
        
        total_rows = len(self.equipment_list) * self.readings_per_equipment
        rows_processed = 0
        
        # Simulation start time
        simulation_start = datetime(year=2026, month=3, day=24, hour=0, minute=0, second=0)
        simulation_end = simulation_start + timedelta(days=self.total_days)
        batch_delta = timedelta(hours=self.batch_hours)
        batch_frames = []

        batch_start = simulation_start

        while batch_start < simulation_end:
            batch_end = min(batch_start + batch_delta, simulation_end)
            logger.info(
                f"Generating batch: {batch_start:%Y-%m-%d %H:%M} to {batch_end:%Y-%m-%d %H:%M}"
            )

            batch_readings = []

            for equipment in self.equipment_list:
                logger.info(f"  Simulating {equipment['id']}...")
                equipment_batch = self._generate_batch(equipment, batch_start, batch_end)
                batch_readings.extend(equipment_batch)
                rows_processed += len(equipment_batch)

                if rows_processed % 10000 == 0 or rows_processed == total_rows:
                    logger.info(f"  Generated {rows_processed:,} / {total_rows:,} rows")

            batch_frames.append(pd.DataFrame(batch_readings))
            batch_start = batch_end
        
        # Convert to DataFrame
        df = pd.concat(batch_frames, ignore_index=True)
        
        # Quick statistics
        logger.info(f"\nDataset complete!")
        logger.info(f"Total rows: {len(df):,}")
        logger.info(f"Date range: {df['timestamp'].min()} to {df['timestamp'].max()}")
        logger.info(f"Equipment count: {df['equipment_id'].nunique()}")
        logger.info(f"Anomaly rate: {df['is_anomaly'].mean()*100:.1f}%")
        
        return df
    
    def save_to_csv(self, df: pd.DataFrame, output_path: str = None):
        """
        Save DataFrame to CSV file.
        
        Args:
            df: DataFrame to save
            output_path: Output file path (uses config default if None)
        """
        if output_path is None:
            output_dir = self.config['simulation'].get('output_dir', 'data')
            output_filename = self.config['simulation'].get('output_filename', 'simulated_sensor_data.csv')
            output_path = f"{output_dir}/{output_filename}"
        
        # Create output directory if needed
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        
        # Save CSV
        df.to_csv(output_path, index=False)
        logger.info(f"Saved to: {output_path}")
        logger.info(f"File size: {Path(output_path).stat().st_size / (1024*1024):.1f} MB")
        
        return output_path

    def generate_batch_to_csv(self, output_path: str = None) -> str:
        """
        Generate the dataset batch by batch and write each batch to CSV.

        This is the preferred mode for the project because it mirrors a batch
        pipeline more closely than building one huge in-memory collection first.
        """
        if output_path is None:
            output_dir = self.config['simulation'].get('output_dir', 'data')
            output_filename = self.config['simulation'].get('output_filename', 'simulated_sensor_data.csv')
            output_path = f"{output_dir}/{output_filename}"

        Path(output_path).parent.mkdir(parents=True, exist_ok=True)

        simulation_start = datetime(year=2026, month=3, day=24, hour=0, minute=0, second=0)
        simulation_end = simulation_start + timedelta(days=self.total_days)
        batch_delta = timedelta(hours=self.batch_hours)

        batch_start = simulation_start
        first_batch = True
        rows_processed = 0

        while batch_start < simulation_end:
            batch_end = min(batch_start + batch_delta, simulation_end)
            logger.info(
                f"Writing batch: {batch_start:%Y-%m-%d %H:%M} to {batch_end:%Y-%m-%d %H:%M}"
            )

            batch_rows = []
            for equipment in self.equipment_list:
                batch_rows.extend(self._generate_batch(equipment, batch_start, batch_end))

            batch_df = pd.DataFrame(batch_rows)
            batch_df.to_csv(output_path, mode='w' if first_batch else 'a', header=first_batch, index=False)

            rows_processed += len(batch_df)
            logger.info(f"  Wrote {len(batch_df):,} rows; total {rows_processed:,}")

            first_batch = False
            batch_start = batch_end

        logger.info(f"Saved to: {output_path}")
        logger.info(f"File size: {Path(output_path).stat().st_size / (1024*1024):.1f} MB")

        return output_path


def main():
    """
    Main entry point. Runs the simulator and saves output.
    """
    try:
        # Initialize simulator
        simulator = SensorSimulator(config_path="config.yml")
        
        # Generate data in batches and save directly to CSV
        output_path = simulator.generate_batch_to_csv()

        # Load the generated file for preview only
        df = pd.read_csv(output_path)
        
        # Show preview
        logger.info("\nFirst 5 rows:")
        logger.info(df.head().to_string())
        
        logger.info("\nLast 5 rows:")
        logger.info(df.tail().to_string())
        
        logger.info("\n✅ Simulation complete! CSV ready for Phase 2 (upload to S3)")
        
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        raise


if __name__ == "__main__":
    main()
