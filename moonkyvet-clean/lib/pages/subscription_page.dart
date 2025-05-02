import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool _isLoading = false;
  bool _hasSubscription = false;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data()?['subscription'];
    if (data != null && data['active'] == true) {
      final expiry = (data['expiryDate'] as Timestamp).toDate();
      if (expiry.isAfter(DateTime.now())) {
        setState(() => _hasSubscription = true);
      }
    }
  }

  Future<void> _activateSubscription() async {
    setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final expiry = now.add(const Duration(days: 30));

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'subscription': {
        'active': true,
        'startDate': now,
        'expiryDate': expiry,
      }
    }, SetOptions(merge: true));

    setState(() {
      _hasSubscription = true;
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subscription activated!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Subscription', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            color: Colors.white10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Subscribe to unlock Moonky AI Chat 🧠🐶',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _hasSubscription ? null : _activateSubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                    child: Text(
                      _hasSubscription ? 'Already Subscribed' : 'Subscribe - 10 RON / month',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  if (_hasSubscription)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'You already have an active subscription 🎉',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
