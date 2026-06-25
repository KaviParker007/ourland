import 'package:flutter/material.dart';

class JobCardDetailsView extends StatelessWidget {
  final Map jobCardDetails;
  const JobCardDetailsView({super.key, required this.jobCardDetails});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Job Card View"),
      ),
      body: SingleChildScrollView(
        child: Card(
          elevation: 10,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 15,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Vehicle Number",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["vehicle_number"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Assigned by",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["assigned_by_name"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Work Start by",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["work_start_by_name"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Work Approved by",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["spare_approved_by_name"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Work Closed by",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["work_closed_by_name"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Work Canceled by",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["work_canceled_by_name"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Work",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["work"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Assigned on",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["assigned_on"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Work Assigned Remark",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["work_assignee_remark"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Work Start at",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["work_start_at"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Mechanics",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["mechanics"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Spares",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["spares"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Spare Requested Date",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["spare_requested_date"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Spare Request Remark",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["spare_request_remark"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Spare Approved on",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["spare_approved_on"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Spare Code",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["spare_code"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Spare Approval Remark",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["spare_approval_remark"] ?? '',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Work Closed at",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["work_closed_at"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Vehicle Incharge Remark",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["vehicle_incharge_remark"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Work Canceled at",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["work_canceled_at"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Cancel Remark",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["cancel_remark"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Cost",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["cost"] == null ? '-' : jobCardDetails["cost"].toString(),
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Remark",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["remark"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text(
                      "Status",
                      style: TextStyle(fontSize: 17, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        jobCardDetails["status"] ?? '-',
                        style: const TextStyle(fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
